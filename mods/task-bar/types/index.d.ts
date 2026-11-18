export type Todo = {
  content: string
  status: 'pending' | 'in_progress' | 'completed'
  activeForm: string
  /** Optional guess, in minutes, of how long the task takes. */
  estimateMinutes?: number
}

/** When a task started and finished, keyed by its `content`. Epoch milliseconds. */
export type Timing = { startedAt?: number; finishedAt?: number }

declare module 'claude-code' {
  interface PluginState {
    'task-bar': { todos: Todo[]; timings: Record<string, Timing>; now: number }
  }
}
