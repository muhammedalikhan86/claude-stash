import type { Answer, Option, Question, YesNo } from '../types'

export type Part =
  | { kind: 'text'; text: string }
  | ({ kind: 'question'; marker: string } & Question)

const MAX_QUESTIONS = 8

// A question is a line outside a code fence with a "?" that ends a sentence.
const isQuestion = (line: string) => /\?(\s|\*|_|\)|$)/.test(line) && !/^\s*>/.test(line)

// Leading list marker ("1. ", "- ") kept apart so only the words are underlined.
const MARKER = /^(\s*(?:\d+[.)]|[-*+])\s+)/

// An option is an indented "a) ..." or "- ..." line under its question.
const OPTION = /^\s+(?:([a-z])\)|[-*+])\s+(\S.*)$/

const PICK_ANY = /\(pick any\)[\s*_.?]*$/i
const RECOMMENDED = /\s*\(Recommended\)$/i

// "(no buttons)" on a heading, lead-in line or list item switches buttons off for its block.
const NO_BUTTONS = /\(no buttons\)[\s*_:.]*$/i

const plain = (text: string) => text.replace(/\*\*|__|`/g, '').trim()

const indentOf = (line: string) => line.length - line.trimStart().length

const headingLevel = (line: string) => line.match(/^(#{1,6})\s/)?.[1].length ?? 0

// First line after the block that the "(no buttons)" line at `at` opens: a heading owns its
// section, a list item its nested lines, any other line its paragraph.
function blockEnd(lines: string[], at: number): number {
  const line = lines[at]
  const level = headingLevel(line)
  let end = at + 1

  if (level > 0) {
    while (end < lines.length && !(headingLevel(lines[end]) > 0 && headingLevel(lines[end]) <= level)) end++
  } else if (MARKER.test(line)) {
    while (end < lines.length && lines[end].trim() !== '' && indentOf(lines[end]) > indentOf(line)) end++
  } else {
    while (end < lines.length && lines[end].trim() !== '') end++
  }

  return end
}

function readOptions(lines: string[], at: number): { options: Option[]; end: number } {
  const options: Option[] = []
  let end = at + 1

  for (; end < lines.length; end++) {
    const m = lines[end].match(OPTION)
    if (m === null || indentOf(lines[end]) <= indentOf(lines[at])) break

    const raw = plain(m[2])
    const text = raw.replace(RECOMMENDED, '').trim()
    options.push({
      label: m[1] === undefined ? text : `${m[1]}) ${text}`,
      text,
      recommended: RECOMMENDED.test(raw),
    })
  }

  // One indented line is not a choice; leave it as ordinary text.
  return options.length < 2 ? { options: [], end: at + 1 } : { options, end }
}

export function splitParts(text: string): Part[] {
  const parts: Part[] = []
  const lines = text.split(/\r?\n/)
  let buffer: string[] = []
  let inFence = false
  let found = 0
  let skipTo = 0

  const flush = () => {
    if (buffer.some(line => line.trim() !== '')) {
      parts.push({ kind: 'text', text: buffer.join('\n') })
    }
    buffer = []
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (/^\s*(```|~~~)/.test(line)) inFence = !inFence

    if (inFence || i < skipTo) {
      buffer.push(line)
    } else if (NO_BUTTONS.test(line)) {
      skipTo = blockEnd(lines, i)
      buffer.push(line)
    } else if (found < MAX_QUESTIONS && isQuestion(line)) {
      flush()
      const marker = line.match(MARKER)?.[1] ?? ''
      const { options, end } = readOptions(lines, i)
      const questionText = plain(line.slice(marker.length))
      parts.push({
        kind: 'question',
        marker: marker.trim(),
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

const keyOf =(q: Question) => JSON.stringify([q.text, q.multi, q.options.map(o => o.label)])

export function sameQuestions(a: Question[], b: Question[]): boolean {
  return a.length === b.length && a.every((q, i) => keyOf(q) === keyOf(b[i]))
}

// A reply is drawn with buttons only while it is an open one, and only with two or more questions.
export function ownsMessage<T extends { questions: Question[] }>(open: T | null, questions: Question[]): open is T {
  return open !== null && questions.length >= 2 && sameQuestions(open.questions, questions)
}

// The open sheet a reply's questions belong to, or null.
export function sheetFor<T extends { questions: Question[] }>(sheets: readonly T[], questions: Question[]): T | null {
  return sheets.find(s => ownsMessage(s, questions)) ?? null
}

// Oldest are dropped past this many open replies.
export const MAX_OPEN = 6

// A new reply's sheet joins the open ones. The same questions asked again replace their old sheet;
// `replaces` (the reply said "(replaces earlier questions)") closes every earlier sheet.
export function addSheet<T extends { questions: Question[] }>(sheets: readonly T[], sheet: T, replaces: boolean): T[] {
  const kept = replaces ? [] : sheets.filter(s => !sameQuestions(s.questions, sheet.questions))
  return [...kept, sheet].slice(-MAX_OPEN)
}
