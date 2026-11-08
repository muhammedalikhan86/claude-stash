export type Option = { label: string; text: string; recommended: boolean }

// No options: a Yes/No question. `multi`: "(pick any)", options toggle independently.
export type Question = { text: string; options: Option[]; multi: boolean }

// `choice` is Yes/No; `picked` indexes options; `other` is the typed answer.
export type Answer = { choice: 'yes' | 'no' | null; picked: number[]; other: string | null }

export type YesNo = 'yes' | 'no'

// One reply's open questions. `typing` is the question whose Other box is open.
export type Pending = { questions: Question[]; picks: (Answer | null)[]; typing: number | null }

declare module 'claude-code' {
  interface PluginState {
    // Before 0.5.0: the one open reply. Read once to carry it over, then left null.
    'answer-buttons': { pending: Pending | null; open: Pending[] }
  }
}
