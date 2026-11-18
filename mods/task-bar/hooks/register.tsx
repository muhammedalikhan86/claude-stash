import { atom, read, update } from 'claude-code'
import type { Hook, Register } from 'claude-code'

import type { Timing, Todo } from '../types'

const todos = atom({ plugin: 'task-bar', key: 'todos' } as const, [] as Todo[])
const timings = atom({ plugin: 'task-bar', key: 'timings' } as const, {} as Record<string, Timing>)
// Written by the ticker so elapsed times redraw while a task runs.
const now = atom({ plugin: 'task-bar', key: 'now' } as const, 0)

const MARK = { completed: '[x]', in_progress: '[>]', pending: '[ ]' } as const
const SET_TASKS = 'mcp__task-bar__set_tasks'
// Cells kept right of the bar for " n/m " and the Clear button.
const CLEAR_CELLS = 10
const TICK_MS = 5000
// A running task never shows more than this share done from its clock alone.
const RUNNING_CAP = 0.95

const formatTime = (ms: number): string => {
  const s = Math.max(0, Math.round(ms / 1000))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m ${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, '0')}m`
}

/** The task's own estimate, else the average of this list's finished tasks, else none. */
const estimateMs = (t: Todo, list: Todo[], times: Record<string, Timing>): number | undefined => {
  if (t.estimateMinutes && t.estimateMinutes > 0) return t.estimateMinutes * 60_000
  const finished = list
    .map(x => times[x.content])
    .filter((x): x is Required<Timing> => !!x?.startedAt && !!x?.finishedAt)
    .map(x => x.finishedAt - x.startedAt)
  if (finished.length === 0) return undefined
  return finished.reduce((a, b) => a + b, 0) / finished.length
}

// Module state: a reload starts it over, and the next update restarts the ticker.
let cancelTick: (() => void) | undefined

// Record start and finish times as statuses change, then keep a ticker
// running only while some task is in progress.
async function apply($: Parameters<Hook<'tool.call'>>[0], list: Todo[]): Promise<void> {
  const t = await $.clock.now()
  await update($, timings, prev => {
    const next: Record<string, Timing> = {}
    for (const todo of list) {
      const old = prev[todo.content] ?? {}
      const startedAt = old.startedAt ?? (todo.status !== 'pending' ? t : undefined)
      const finishedAt = todo.status === 'completed' ? (old.finishedAt ?? t) : undefined
      next[todo.content] = { startedAt, finishedAt }
    }
    return next
  })
  await update($, todos, () => list)
  await update($, now, () => t)

  const isRunning = list.some(x => x.status === 'in_progress')
  if (isRunning && !cancelTick) {
    const timer = $.clock.every(TICK_MS, async () => {
      const tick = await $.clock.now()
      await update($, now, () => tick)
    })
    cancelTick = () => timer.cancel()
  } else if (!isRunning && cancelTick) {
    cancelTick()
    cancelTick = undefined
  }
}

export const register: Register = on => {
  // Sessions without TodoWrite get their own tool to call instead.
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'set_tasks',
      description:
        'Show the current task list in the pinned progress bar above the prompt. Send the WHOLE list every time: when you start a multi-step job, finish a step, add a step, or change the plan. Send an empty list to clear it. Give each task an estimateMinutes guess when you can.',
      isDeferred: false,
      inputSchema: {
        type: 'object',
        properties: {
          todos: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                content: { type: 'string', description: 'Task, e.g. "Print headings 1-50"' },
                status: { type: 'string', enum: ['pending', 'in_progress', 'completed'] },
                activeForm: { type: 'string', description: 'Same task as it is happening, e.g. "Printing headings 1-50"' },
                estimateMinutes: {
                  type: 'number',
                  description: 'Optional: your guess of how many minutes the task takes, e.g. 3',
                },
              },
              required: ['content', 'status', 'activeForm'],
            },
          },
        },
        required: ['todos'],
      },
    })

    return next(e)
  })

  on('tool.call', { tool: SET_TASKS }, async ($, e, next) => {
    const list = (e as unknown as { todos: Todo[] }).todos ?? []
    await apply($, list)

    return { result: `Task bar updated: ${list.length} tasks.` }
  })

  // Every TodoWrite sends the whole list, so one write covers add, change and re-plan.
  on('tool.call', { tool: 'TodoWrite' }, async ($, e, next) => {
    await apply($, e.todos as Todo[])

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, todos)

    if (e.props.hasSurvey || list.length === 0) {
      return next(e)
    }

    const times = await read($, timings)
    const t = Math.max(await read($, now), 1)
    const { Box, Button, Text } = $.ui.resolve(e)

    // Each task's share done: 1 when finished, its clock against its estimate while running.
    const rows = list.map(todo => {
      const time = times[todo.content] ?? {}
      const est = estimateMs(todo, list, times)
      const elapsed = time.startedAt ? (time.finishedAt ?? t) - time.startedAt : 0
      let share = 0
      if (todo.status === 'completed') share = 1
      else if (todo.status === 'in_progress' && est) share = Math.min(elapsed / est, RUNNING_CAP)
      return { todo, est, elapsed, share }
    })

    const done = list.filter(x => x.status === 'completed').length
    const progress = rows.reduce((a, r) => a + r.share, 0) / list.length
    const count = ` ${done}/${list.length} `
    const barWidth = Math.max(10, e.props.bodyColumns - count.length - CLEAR_CELLS)
    const filled = Math.round(progress * barWidth)
    const bar = '█'.repeat(filled) + '░'.repeat(barWidth - filled)

    const detail = (r: (typeof rows)[number]): string => {
      if (r.todo.status === 'completed') return r.elapsed ? `  (${formatTime(r.elapsed)})` : ''
      if (r.todo.status === 'in_progress') {
        if (!r.est) return `  (${formatTime(r.elapsed)})`
        const pct = Math.round(r.share * 100)
        return `  ${pct}% done (${formatTime(r.elapsed)} / ~${formatTime(r.est)})`
      }
      return r.est ? `  (~${formatTime(r.est)})` : ''
    }

    // Right end, after this tree: the engine's own [-] collapse mark.
    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Box flexGrow={1}>
            <Text wrap="clip">{bar}</Text>
          </Box>
          <Text>{count}</Text>
          <Button key="clear" label="Clear" onPress={async () => { await update($, todos, () => []); await update($, timings, () => ({})) }} />
        </Box>
        {rows.map((r, i) => (
          <Text key={String(i)} wrap="truncate-end" dimColor={r.todo.status !== 'in_progress'}>
            {MARK[r.todo.status]} {r.todo.status === 'in_progress' ? r.todo.activeForm : r.todo.content}
            {detail(r)}
          </Text>
        ))}
      </Box>
    )
  })
}
