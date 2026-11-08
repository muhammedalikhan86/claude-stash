import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Todo } from '../types'

const todos = atom({ plugin: 'task-bar', key: 'todos' } as const, [] as Todo[])

const WIDTH = 20
const MARK = { completed: '[x]', in_progress: '[>]', pending: '[ ]' } as const

const SET_TASKS = 'mcp__task-bar__set_tasks'

export const register: Register = on => {
  // Sessions without TodoWrite get their own tool to call instead.
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'set_tasks',
      description:
        'Show the current task list in the pinned progress bar above the prompt. Send the WHOLE list every time: when you start a multi-step job, finish a step, add a step, or change the plan. Send an empty list to clear it.',
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
    await update($, todos, () => list)

    return { result: `Task bar updated: ${list.length} tasks.` }
  })

  // Every TodoWrite sends the whole list, so one write covers add, change and re-plan.
  on('tool.call', { tool: 'TodoWrite' }, async ($, e, next) => {
    await update($, todos, () => e.todos)

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, todos)

    if (e.props.hasSurvey || list.length === 0) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const done = list.filter(t => t.status === 'completed').length
    const filled = Math.round((done / list.length) * WIDTH)
    const bar = '█'.repeat(filled) + '░'.repeat(WIDTH - filled)
    const isAllDone = done === list.length

    return (
      <Box flexDirection="column">
        <Box>
          <Text>
            {bar} {done}/{list.length}
            {isAllDone ? ' all done ' : ' '}
          </Text>
          <Button
            key="clear"
            label="Clear"
            onPress={() => update($, todos, () => [])}
          />
        </Box>
        {list.map((t, i) => (
          <Text key={i} dimColor={t.status !== 'in_progress'}>
            {MARK[t.status]} {t.status === 'in_progress' ? t.activeForm : t.content}
          </Text>
        ))}
      </Box>
    )
  })
}
