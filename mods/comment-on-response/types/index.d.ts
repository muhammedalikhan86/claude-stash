export type Pending = { quote: string; comment: string }

declare module 'claude-code' {
  interface PluginState {
    'comment-on-response': { pending: Shaped<Pending | null> }
  }
}
