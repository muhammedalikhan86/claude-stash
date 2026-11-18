import { atom, read, update } from 'claude-code'
import type { Hook, Register } from 'claude-code'

import type { Helper, Timing, Todo } from '../types'

// The main session's own list.
const todos = atom({ plugin: 'task-bar', key: 'todos' } as const, [] as Todo[])
// Each helper's (subagent's) own list, keyed by agent id, so a helper never replaces the main list.
const helpers = atom({ plugin: 'task-bar', key: 'helpers' } as const, {} as Record<string, Helper>)
const timings = atom({ plugin: 'task-bar', key: 'timings' } as const, {} as Record<string, Timing>)
// Written by the ticker so elapsed times redraw while a task runs.
const now = atom({ plugin: 'task-bar', key: 'now' } as const, 0)

const MARK = { completed: '[x]', in_progress: '[>]', pending: '[ ]' } as const
const SET_TASKS = 'mcp__task-bar__set_tasks'
const MAIN = 'main'
// Cells kept right of the bar for " n/m " and the Clear button.
const CLEAR_CELLS = 10
const TICK_MS = 5000
// A running task never shows more than this share done from its clock alone.
const RUNNING_CAP = 0.95
const FINISHED = ['completed', 'failed', 'killed']

const timingKey = (owner: string, content: string): string => `${owner}\u0000${content}`

const formatTime = (ms: number): string => {
  const s = Math.max(0, Math.round(ms / 1000))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m ${String(s % 60).padStart(2, '0')}s`
  return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, '0')}m`
}

/** The task's own estimate, else the average of its list's finished tasks, else none. */
function estimateMs(t: Todo, owner: string, list: Todo[], times: Record<string, Timing>): number | undefined {
  if (t.estimateMinutes && t.estimateMinutes > 0) return t.estimateMinutes * 60_000
  const finished = list
    .map(x => times[timingKey(owner, x.content)])
    .filter((x): x is Required<Timing> => !!x?.startedAt && !!x?.finishedAt)
    .map(x => x.finishedAt - x.startedAt)
  if (finished.length === 0) return undefined
  return finished.reduce((a, b) => a + b, 0) / finished.length
}

// Module state: a reload starts it over, and the next update restarts the ticker.
let cancelTick: (() => void) | undefined

// Store one owner's list (the main session's, or one helper's), record start and
// finish times as statuses change, and keep a ticker running only while some task runs.
async function apply($: Parameters<Hook<'tool.call'>>[0], agentId: string | undefined, list: Todo[]): Promise<void> {
  const owner = agentId ?? MAIN
  const t = await $.clock.now()

  await update($, timings, prev => {
    const next: Record<string, Timing> = {}
    // Keep every other owner's times; rebuild this owner's from its new list.
    for (const [k, v] of Object.entries(prev)) if (!k.startsWith(`${owner}\u0000`)) next[k] = v
    for (const todo of list) {
      const key = timingKey(owner, todo.content)
      const old = prev[key] ?? {}
      const startedAt = old.startedAt ?? (todo.status !== 'pending' ? t : undefined)
      const finishedAt = todo.status === 'completed' ? (old.finishedAt ?? t) : undefined
      next[key] = { startedAt, finishedAt }
    }
    return next
  })

  if (agentId) {
    const agents = await $.agent.list()
    const label = agents.find(a => a.id === agentId)?.description || `Helper ${agentId.slice(0, 6)}`
    await update($, helpers, prev => {
      const next = { ...prev }
      if (list.length === 0) delete next[agentId]
      else next[agentId] = { label, todos: list }
      return next
    })
  } else {
    await update($, todos, () => list)
    // A main-list update drops the lists of helpers that have finished.
    const agents = await $.agent.list()
    await update($, helpers, prev => {
      const next: Record<string, Helper> = {}
      for (const [id, h] of Object.entries(prev)) {
        const agent = agents.find(a => a.id === id)
        if (!agent || !FINISHED.includes(agent.status)) next[id] = h
      }
      return next
    })
  }
  await update($, now, () => t)

  const all = [...(await read($, todos)), ...Object.values(await read($, helpers)).flatMap(h => h.todos)]
  const isRunning = all.some(x => x.status === 'in_progress')
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
        'Show the current task list in the pinned progress bar above the prompt. Send the WHOLE list every time: when you start a multi-step job, finish a step, add a step, or change the plan. Send an empty list to clear it. A helper (subagent) has its own list, drawn indented under its name, so it never replaces its caller\'s list. Give each task an estimateMinutes guess when you can, and a group (e.g. a worker\'s name) to draw parallel work under one heading.',
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
                group: {
                  type: 'string',
                  description: 'Optional: the heading to draw this task under, e.g. a worker or agent name. Tasks without one come first.',
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
    await apply($, e.agentId, list)

    return { result: `Task bar updated: ${list.length} tasks.` }
  })

  // Every TodoWrite sends the whole list, so one write covers add, change and re-plan.
  on('tool.call', { tool: 'TodoWrite' }, async ($, e, next) => {
    await apply($, e.agentId, e.todos as Todo[])

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const main = await read($, todos)
    const helperLists = Object.entries(await read($, helpers))

    if (e.props.hasSurvey || (main.length === 0 && helperLists.length === 0)) {
      return next(e)
    }

    const times = await read($, timings)
    const t = Math.max(await read($, now), 1)
    const { Box, Button, Text } = $.ui.resolve(e)

    // Each task's share done: 1 when finished, its clock against its estimate while running.
    const measure = (owner: string, list: Todo[]) =>
      list.map(todo => {
        const time = times[timingKey(owner, todo.content)] ?? {}
        const est = estimateMs(todo, owner, list, times)
        const elapsed = time.startedAt ? (time.finishedAt ?? t) - time.startedAt : 0
        let share = 0
        if (todo.status === 'completed') share = 1
        else if (todo.status === 'in_progress' && est) share = Math.min(elapsed / est, RUNNING_CAP)
        return { todo, est, elapsed, share }
      })
    type Row = ReturnType<typeof measure>[number]

    // Sections: the main list's ungrouped tasks, then one per `group`, then one per helper.
    type Section = { heading?: string; rows: Row[] }
    const mainRows = measure(MAIN, main)
    const sections: Section[] = [{ rows: mainRows.filter(r => !r.todo.group) }]
    for (const r of mainRows) {
      if (!r.todo.group) continue
      let s = sections.find(x => x.heading === r.todo.group)
      if (!s) sections.push((s = { heading: r.todo.group, rows: [] }))
      s.rows.push(r)
    }
    for (const [id, h] of helperLists) sections.push({ heading: h.label, rows: measure(id, h.todos) })

    const allRows = sections.flatMap(s => s.rows)
    const done = allRows.filter(r => r.todo.status === 'completed').length
    const progress = allRows.length ? allRows.reduce((a, r) => a + r.share, 0) / allRows.length : 0
    const count = ` ${done}/${allRows.length} `
    const barWidth = Math.max(10, e.props.bodyColumns - count.length - CLEAR_CELLS)
    const filled = Math.round(progress * barWidth)
    const bar = '█'.repeat(filled) + '░'.repeat(barWidth - filled)

    const detail = (r: Row): string => {
      if (r.todo.status === 'completed') return r.elapsed ? `  (${formatTime(r.elapsed)})` : ''
      if (r.todo.status === 'in_progress') {
        if (!r.est) return `  (${formatTime(r.elapsed)})`
        const pct = Math.round(r.share * 100)
        return `  ${pct}% done (${formatTime(r.elapsed)} / ~${formatTime(r.est)})`
      }
      return r.est ? `  (~${formatTime(r.est)})` : ''
    }

    const lines: { key: string; text: string; dim: boolean }[] = []
    sections.forEach((s, si) => {
      const indent = s.heading ? '    ' : ''
      if (s.heading) {
        const sDone = s.rows.filter(r => r.todo.status === 'completed').length
        const isActive = s.rows.some(r => r.todo.status === 'in_progress')
        lines.push({ key: `h${si}`, text: `  ▸ ${s.heading}  ${sDone}/${s.rows.length}`, dim: !isActive })
      }
      s.rows.forEach((r, ri) => {
        const name = r.todo.status === 'in_progress' ? r.todo.activeForm : r.todo.content
        lines.push({
          key: `r${si}-${ri}`,
          text: `${indent}${MARK[r.todo.status]} ${name}${detail(r)}`,
          dim: r.todo.status !== 'in_progress',
        })
      })
    })

    const clearAll = async () => {
      await update($, todos, () => [])
      await update($, helpers, () => ({}))
      await update($, timings, () => ({}))
    }

    // Right end, after this tree: the engine's own [-] collapse mark.
    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Box flexGrow={1}>
            <Text wrap="clip">{bar}</Text>
          </Box>
          <Text>{count}</Text>
          <Button key="clear" label="Clear" onPress={clearAll} />
        </Box>
        {lines.map(l => (
          <Text key={l.key} wrap="truncate-end" dimColor={l.dim}>
            {l.text}
          </Text>
        ))}
      </Box>
    )
  })
}
