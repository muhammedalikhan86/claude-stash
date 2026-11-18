export type Todo = {
  content: string
  status: 'pending' | 'in_progress' | 'completed'
  activeForm: string
  /** Optional guess, in minutes, of how long the task takes. */
  estimateMinutes?: number
  /** Optional group the task is drawn under, e.g. a worker's name. Tasks without one come first. */
  group?: string
}

/** When a task started and finished, keyed by owner and `content`. Epoch milliseconds. */
export type Timing = { startedAt?: number; finishedAt?: number }

/** One helper's (subagent's) own list, keyed by its agent id. */
export type Helper = { label: string; todos: Todo[] }

declare module 'claude-code' {
  interface PluginState {
    'task-bar': {
      todos: Todo[]
      helpers: Record<string, Helper>
      timings: Record<string, Timing>
      now: number
    }
  }
}
