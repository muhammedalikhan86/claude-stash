import type { Answer, Option, Question, YesNo } from '../types'

export type Part =
  | { kind: 'text'; text: string }
  | ({ kind: 'question'; marker: string } & Question)

const MAX_QUESTIONS = 8

// Only a line tagged "[Question]:" is a question, so a rhetorical "?" in ordinary text never is.
// It may follow a list marker or sit in bold; the "?" is optional (a request for an answer counts).
const QUESTION = /^(\s*(?:\d+[.)]|[-*+])\s+)?\[Question\]\s*:\s*(\S.*)$/i

// Its answers: an "Options:" line under it, each option between guillemets, numbered:
//   Options: 1. «Sync» 2. «Backfill» 3. «Other»
// The guillemets may carry on over the following lines, up to a blank line.
const OPTIONS = /^\s*(?:(?:\d+[.)]|[-*+])\s+)?Options\s*:\s*(.*)$/i
const QUOTED = /«([^«»]*)»/g

const PICK_ANY = /\(pick any\)[\s*_.?]*$/i
const RECOMMENDED = /\s*\(Recommended\)$/i

// "Other" is always drawn as its own type-your-answer button, so a listed one is not an option.
const OTHER = /^other\b[^a-z]*(?:\(.*\))?[.:]?$/i

const plain = (text: string) => text.replace(/\*\*|__|`/g, '').trim()

// The option texts on an "Options:" line. Guillemets first; failing those, "1. A 2. B" or "A | B".
function optionTexts(lines: string[]): string[] {
  const joined = lines.join(' ')
  const quoted = [...joined.matchAll(QUOTED)].map(m => m[1].trim())
  if (quoted.length > 0) return quoted

  const bare = joined.trim().replace(/^\((.*)\)$/, '$1')
  const parts = /\|/.test(bare) ? bare.split('|') : bare.split(/(?:^|\s)\d+[.)]\s+/)
  return parts.map(t => t.trim().replace(/[,;]$/, '').trim()).filter(t => t !== '')
}

// The "Options:" block after the question at `at`: blank lines may come between; the options may
// carry on over following lines that hold guillemets.
function readOptions(lines: string[], at: number): { options: Option[]; end: number } {
  let i = at + 1
  while (i < lines.length && lines[i].trim() === '') i++

  const head = i < lines.length ? plain(lines[i]).match(OPTIONS) : null
  if (head === null) return { options: [], end: at + 1 }

  const block = [head[1]]
  let end = i + 1
  while (end < lines.length && lines[end].trim() !== '' && /«/.test(lines[end]) && !QUESTION.test(plain(lines[end]))) {
    block.push(plain(lines[end]))
    end++
  }

  const options = optionTexts(block)
    .map(raw => ({ raw, text: raw.replace(RECOMMENDED, '').trim() }))
    .filter(o => o.text !== '' && !OTHER.test(o.text))
    .map((o, k) => ({ label: `${k + 1}. ${o.text}`, text: o.text, recommended: RECOMMENDED.test(o.raw) }))

  return { options, end }
}

export function splitParts(text: string): Part[] {
  const parts: Part[] = []
  const lines = text.split(/\r?\n/)
  let buffer: string[] = []
  let inFence = false
  let found = 0

  const flush = () => {
    if (buffer.some(line => line.trim() !== '')) {
      parts.push({ kind: 'text', text: buffer.join('\n') })
    }
    buffer = []
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (/^\s*(```|~~~)/.test(line)) inFence = !inFence

    const m = inFence || /^\s*>/.test(line) ? null : plain(line).match(QUESTION)
    if (m !== null && found < MAX_QUESTIONS) {
      flush()
      const { options, end } = readOptions(lines, i)
      const questionText = m[2].trim()
      parts.push({
        kind: 'question',
        marker: (m[1] ?? '').trim(),
        text: questionText,
        options,
        multi: options.length > 0 && PICK_ANY.test(questionText),
      })
      found += 1
      i = end - 1
    } else {
      buffer.push(line)
    }
  }
  flush()

  return parts
}

export function findAsked(text: string): Question[] {
  return splitParts(text).flatMap(part =>
    part.kind === 'question' ? [{ text: part.text, options: part.options, multi: part.multi }] : [],
  )
}

export function findQuestions(text: string): string[] {
  return findAsked(text).map(q => q.text)
}

const norm = (a: Answer): Answer | null =>
  a.choice === null && a.picked.length === 0 && a.other === null ? null : a

// A press on Yes/No (`{ yn }`) or on option `i` (`{ option }`); a second press un-picks.
export function togglePick(
  q: Question,
  old: Answer | null,
  press: { yn: YesNo } | { option: number },
): Answer | null {
  if ('yn' in press) {
    return old?.choice === press.yn ? null : { choice: press.yn, picked: [], other: null }
  }

  const has = old?.picked.includes(press.option) ?? false

  if (q.multi) {
    const picked = has
      ? old!.picked.filter(i => i !== press.option)
      : [...(old?.picked ?? []), press.option].sort((a, b) => a - b)
    return norm({ choice: null, picked, other: old?.other ?? null })
  }

  return has ? null : { choice: null, picked: [press.option], other: null }
}

// Typed text; empty clears it. Alone on a Yes/No or one-of question, beside the picks on pick-any.
export function setOther(q: Question, old: Answer | null, text: string): Answer | null {
  const other = text.replace(/\s*\n\s*/g, ' ').trim() || null
  return norm({ choice: null, picked: q.multi ? (old?.picked ?? []) : [], other })
}

const said = (q: Question, a: Answer | null): string => {
  if (a === null) return 'Not answered'
  if (a.choice !== null) return a.choice === 'yes' ? 'Yes' : 'No'

  return [...a.picked.map(i => q.options[i].label), ...(a.other === null ? [] : [`Other: ${a.other}`])].join('; ')
}

// Every question listed; a skipped one is said to be skipped, never assumed.
export function answersText(p: { questions: Question[]; picks: (Answer | null)[] }): string {
  const lines = p.questions.map((q, i) => `${i + 1}. ${q.text}\n   → ${said(q, p.picks[i] ?? null)}`)
  const skipped = p.picks.some(pick => pick === null)
  const rule = skipped
    ? '\n\nFor any question marked "Not answered", do not assume an answer: ask me about it before acting on it.'
    : ''

  return `My answers to your questions:\n${lines.join('\n')}${rule}`
}

// A typed draft goes in front of the answers, a blank line between; no draft, just the answers.
export function withAnswers(draft: string, answers: string): string {
  const typed = draft.trim()
  return typed === '' ? answers : `${typed}\n\n${answers}`
}

// At least one question has a pick; only then is there anything to send.
export function hasAnswers<T extends { picks: (Answer | null)[] }>(p: T | null): p is T {
  return p !== null && p.picks.some(pick => pick !== null)
}

const keyOf = (q: Question) => JSON.stringify([q.text, q.multi, q.options.map(o => o.label)])

export function sameQuestions(a: Question[], b: Question[]): boolean {
  return a.length === b.length && a.every((q, i) => keyOf(q) === keyOf(b[i]))
}

// A reply is drawn with buttons only while it is an open one with at least one question.
export function ownsMessage<T extends { questions: Question[] }>(open: T | null, questions: Question[]): open is T {
  return open !== null && questions.length >= 1 && sameQuestions(open.questions, questions)
}

// The open sheet a reply's questions belong to, or null.
export function sheetFor<T extends { questions: Question[] }>(sheets: readonly T[], questions: Question[]): T | null {
  return sheets.find(s => ownsMessage(s, questions)) ?? null
}

// A new reply's sheet joins the open ones. Only Submit or Dismiss closes a sheet, so nothing here
// drops one: the same questions asked again keep their existing sheet and its picks.
export function addSheet<T extends { questions: Question[] }>(sheets: readonly T[], sheet: T): T[] {
  return sheets.some(s => sameQuestions(s.questions, sheet.questions)) ? [...sheets] : [...sheets, sheet]
}
