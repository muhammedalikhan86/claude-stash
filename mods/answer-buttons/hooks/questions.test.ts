import { expect, test } from 'claude-code/testing'

import type { Question } from '../types'
import {
  addSheet,
  MAX_OPEN,
  sheetFor,
  answersText,
  findAsked,
  findQuestions,
  hasAnswers,
  ownsMessage,
  setOther,
  splitParts,
  togglePick,
  withAnswers,
} from './questions'

const yn = (text: string): Question => ({ text, options: [], multi: false })

const reply = `Two things to confirm before I start:

1. **Luke's three new sections**: copy them in word for word, and write them into the proposal? I'd do both.
2. When Luke replies, we repeat the same loop: his copy first, then ours. Agreed?

Say go and I'll start with step 1.`

test('finds the numbered questions and keeps their numbers apart', async () => {
  expect(findQuestions(reply)).toEqual([
    "Luke's three new sections: copy them in word for word, and write them into the proposal? I'd do both.",
    'When Luke replies, we repeat the same loop: his copy first, then ours. Agreed?',
  ])
  const markers = splitParts(reply).flatMap(p => (p.kind === 'question' ? [p.marker] : []))
  expect(markers).toEqual(['1.', '2.'])
})

test('ignores a question mark inside a code block', async () => {
  expect(findQuestions('Here:\n```\nif (a?) b\nwhy?\n```\nDone.')).toEqual([])
})

test('a reply with no questions has none', async () => {
  expect(findQuestions('All done. The tests pass.')).toEqual([])
})

test('a plain question line has no options and is Yes/No', async () => {
  expect(findAsked('Ship it?')).toEqual([yn('Ship it?')])
})

test('lettered options under a question become its options', async () => {
  const [q] = findAsked('Which first?\n  a) Sync\n  b) Backfill')
  expect(q.options.map(o => o.label)).toEqual(['a) Sync', 'b) Backfill'])
  expect(q.options.map(o => o.text)).toEqual(['Sync', 'Backfill'])
  expect(q.multi).toBe(false)
})

test('dash options become options, and the option lines are not text or questions', async () => {
  const parts = splitParts('Pick one?\n  - Is it fast?\n  - Is it safe?\nThen go.')
  expect(parts.map(p => p.kind)).toEqual(['question', 'text'])
  const q = parts[0]
  expect(q.kind === 'question' && q.options.map(o => o.label)).toEqual(['Is it fast?', 'Is it safe?'])
})

test('a single indented line is not a choice', async () => {
  const [q] = findAsked('Ready?\n  - just a note')
  expect(q.options).toEqual([])
})

test('an option ending in (Recommended) is marked and the tag is stripped from its text', async () => {
  const [q] = findAsked('Which?\n  a) Sync first (Recommended)\n  b) Wait')
  expect(q.options[0]).toEqual({ label: 'a) Sync first', text: 'Sync first', recommended: true })
  expect(q.options[1].recommended).toBe(false)
})

test('(pick any) makes the options multi-select; without options it stays Yes/No', async () => {
  const [multi] = findAsked('Which ones? (pick any)\n  a) One\n  b) Two')
  expect(multi.multi).toBe(true)
  const [bare] = findAsked('Which ones? (pick any)')
  expect(bare.multi).toBe(false)
})

test('a choice answer is sent as the option label', async () => {
  const q = findAsked('Which first?\n  a) Sync first\n  b) Backfill')[0]
  const picks = [togglePick(q, null, { option: 0 })]
  expect(answersText({ questions: [q], picks })).toContain('1. Which first?\n   → a) Sync first')
})

test('a one-of question swaps its pick, and a second press un-picks', async () => {
  const q = findAsked('Which?\n  a) One\n  b) Two')[0]
  const a = togglePick(q, null, { option: 0 })
  const b = togglePick(q, a, { option: 1 })
  expect(b?.picked).toEqual([1])
  expect(togglePick(q, b, { option: 1 })).toBe(null)
})

test('a pick-any question toggles options independently and sends every pick', async () => {
  const q = findAsked('Which? (pick any)\n  a) One\n  b) Two\n  c) Three')[0]
  let a = togglePick(q, null, { option: 2 })
  a = togglePick(q, a, { option: 0 })
  expect(a?.picked).toEqual([0, 2])
  expect(answersText({ questions: [q], picks: [a] })).toContain('→ a) One; c) Three')
  a = togglePick(q, a, { option: 0 })
  expect(a?.picked).toEqual([2])
})

test('Other text is sent as the answer, and replaces a Yes/No pick', async () => {
  const q = yn('Ship it?')
  const picked = togglePick(q, null, { yn: 'yes' })
  const other = setOther(q, picked, '  not until Friday ')
  expect(other).toEqual({ choice: null, picked: [], other: 'not until Friday' })
  expect(answersText({ questions: [q], picks: [other] })).toContain('→ Other: not until Friday')
})

test('Other on a pick-any question sits beside the picks; empty text clears it', async () => {
  const q = findAsked('Which? (pick any)\n  a) One\n  b) Two')[0]
  const a = setOther(q, togglePick(q, null, { option: 1 }), 'something else')
  expect(answersText({ questions: [q], picks: [a] })).toContain('→ b) Two; Other: something else')
  expect(setOther(q, a, '')?.picked).toEqual([1])
  expect(setOther(yn('Ship it?'), setOther(yn('Ship it?'), null, 'x'), '  ')).toBe(null)
})

test('lines under a (no buttons) lead-in are skipped until the blank line', async () => {
  const text = 'Things to look for (no buttons):\n- Is the fan loud?\n- Is it warm?\n\nShip it?\nAgreed?'
  expect(findQuestions(text)).toEqual(['Ship it?', 'Agreed?'])
})

test('a (no buttons) heading skips its whole section, up to the next heading', async () => {
  const text = '## Checklist (no buttons)\n\n- Is it loud?\n\n- Is it warm?\n\n## Decisions\nShip it?'
  expect(findQuestions(text)).toEqual(['Ship it?'])
})

test('a (no buttons) list item skips itself and its nested lines only', async () => {
  const text = '- Look for (no buttons)\n  - Is it loud?\n- Ship it?'
  expect(findQuestions(text)).toEqual(['Ship it?'])
})

test('a (no buttons) tag inside a code block does nothing', async () => {
  expect(findQuestions('```\nx (no buttons)\n```\nShip it?')).toEqual(['Ship it?'])
})

test('a reply can mix Yes/No and choice questions', async () => {
  const text = `1. Ship it today?
2. Which order?
   a) Sync first (Recommended)
   b) Backfill first
3. Anything to add? (pick any)
   - Docs
   - Tests`
  const qs = findAsked(text)
  expect(qs.map(q => q.options.length)).toEqual([0, 2, 2])
  expect(qs.map(q => q.multi)).toEqual([false, false, true])
  const out = answersText({
    questions: qs,
    picks: [togglePick(qs[0], null, { yn: 'no' }), togglePick(qs[1], null, { option: 1 }), null],
  })
  expect(out).toContain('1. Ship it today?\n   → No')
  expect(out).toContain('2. Which order?\n   → b) Backfill first')
  expect(out).toContain('3. Anything to add? (pick any)\n   → Not answered')
  expect(out).toContain('do not assume')
})

test('a skipped question is sent as not answered, never as yes', async () => {
  const text = answersText({
    questions: [yn('Copy it?'), yn('Agreed?')],
    picks: [{ choice: 'no', picked: [], other: null }, null],
  })
  expect(text).toContain('1. Copy it?\n   → No')
  expect(text).toContain('2. Agreed?\n   → Not answered')
  expect(text).toContain('do not assume')
  expect(text).not.toContain('Yes')
})

test('all answered adds no warning', async () => {
  const text = answersText({
    questions: [yn('Copy it?'), yn('Agreed?')],
    picks: [
      { choice: 'yes', picked: [], other: null },
      { choice: 'no', picked: [], other: null },
    ],
  })
  expect(text).not.toContain('Not answered')
  expect(text).not.toContain('do not assume')
})

test('a reply with one question is never drawn with buttons', async () => {
  expect(ownsMessage({ questions: [yn('Ready?')] }, [yn('Ready?')])).toBe(false)
})

test('once the buttons are closed, no reply is drawn by the mod', async () => {
  expect(ownsMessage(null, [yn('Copy it?'), yn('Agreed?')])).toBe(false)
})

test('a later reply with different questions is not the open one', async () => {
  expect(ownsMessage({ questions: [yn('Copy it?'), yn('Agreed?')] }, [yn('Copy it?'), yn('Ship it?')])).toBe(false)
})

test('the same text with different options is not the open reply', async () => {
  const a = findAsked('1. Which?\n  a) One\n  b) Two\n2. Ok?')
  const b = findAsked('1. Which?\n  a) One\n  b) Three\n2. Ok?')
  expect(ownsMessage({ questions: a }, b)).toBe(false)
})

test('the open reply with two or more questions gets buttons', async () => {
  expect(ownsMessage({ questions: [yn('Copy it?'), yn('Agreed?')] }, [yn('Copy it?'), yn('Agreed?')])).toBe(true)
})

test('a typed draft goes in front of the answers with a blank line between', async () => {
  expect(withAnswers('Go ahead.', 'My answers to your questions:\n1. A?\n   → Yes')).toBe(
    'Go ahead.\n\nMy answers to your questions:\n1. A?\n   → Yes',
  )
})

test('no draft, or a blank one, sends just the answers', async () => {
  expect(withAnswers('', 'answers')).toBe('answers')
  expect(withAnswers('  \n ', 'answers')).toBe('answers')
})

test('Submit has something to send only once a question is answered', async () => {
  const yes = { choice: 'yes' as const, picked: [], other: null }
  expect(hasAnswers(null)).toBe(false)
  expect(hasAnswers({ picks: [null, null] })).toBe(false)
  expect(hasAnswers({ picks: [null, yes] })).toBe(true)
})

const sheet = (...texts: string[]) => ({ questions: texts.map(yn), picks: texts.map(() => null), typing: null })

test('a new reply with questions keeps the earlier open ones', async () => {
  const a = sheet('Copy it?', 'Agreed?')
  const b = sheet('Ship it?', 'Today?')
  const open = addSheet([a], b, false)
  expect(open).toEqual([a, b])
  expect(sheetFor(open, a.questions)).toBe(a)
  expect(sheetFor(open, b.questions)).toBe(b)
})

test('"(replaces earlier questions)" closes every earlier sheet', async () => {
  const b = sheet('Ship it?', 'Today?')
  expect(addSheet([sheet('Copy it?', 'Agreed?')], b, true)).toEqual([b])
})

test('the same questions asked again replace their old sheet, not add a second', async () => {
  const old = { ...sheet('Copy it?', 'Agreed?'), picks: [{ choice: 'yes' as const, picked: [], other: null }, null] }
  const fresh = sheet('Copy it?', 'Agreed?')
  expect(addSheet([old], fresh, false)).toEqual([fresh])
})

test('only the newest few sheets stay open', async () => {
  let open: ReturnType<typeof sheet>[] = []
  for (let i = 0; i < MAX_OPEN + 2; i++) open = addSheet(open, sheet(`A${i}?`, `B${i}?`), false)
  expect(open.length).toBe(MAX_OPEN)
  expect(open[0].questions[0].text).toBe('A2?')
})

test('a reply that is no open sheet gets no buttons', async () => {
  expect(sheetFor([sheet('Copy it?', 'Agreed?')], [yn('Other?'), yn('Thing?')])).toBe(null)
})
