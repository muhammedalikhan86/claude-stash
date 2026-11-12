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

const reply = `Two things to settle before I start.

Is the copy right? I checked it twice, so yes.

[Question]: Which order should I run them in?
Options: 1. «Sync first (Recommended)» 2. «Backfill first» 3. «Other»

[Question]: Tell me the port to use
Options: 1. «4200» 2. «4300» 3. «Other»

Say go and I'll start.`

test('only [Question]: lines are questions; a rhetorical one is not', async () => {
  expect(findQuestions(reply)).toEqual(['Which order should I run them in?', 'Tell me the port to use'])
})

test('a question needs no question mark', async () => {
  expect(findQuestions('[Question]: Let me know which folder')).toEqual(['Let me know which folder'])
})

test('a plain "?" line is never a question', async () => {
  expect(findQuestions('Ship it?\nAgreed?\n1. Ready?')).toEqual([])
})

test('guillemet options become numbered options; Other is never one of them', async () => {
  const [q] = findAsked(reply)
  expect(q.options.map(o => o.label)).toEqual(['1. Sync first', '2. Backfill first'])
  expect(q.options.map(o => o.text)).toEqual(['Sync first', 'Backfill first'])
  expect(q.options.map(o => o.recommended)).toEqual([true, false])
  expect(q.multi).toBe(false)
})

test('an option may hold commas, pipes, digits and quote marks', async () => {
  const [q] = findAsked('[Question]: Which?\nOptions: 1. «Use "fast", then 2. slow | safe» 2. «No»')
  expect(q.options.map(o => o.text)).toEqual(['Use "fast", then 2. slow | safe', 'No'])
})

test('options may run over several lines, up to a blank line', async () => {
  const parts = splitParts('[Question]: Which?\nOptions:\n1. «One»\n2. «Two»\n3. «Other»\n\nThen go.')
  expect(parts.map(p => p.kind)).toEqual(['question', 'text'])
  const q = parts[0]
  expect(q.kind === 'question' && q.options.map(o => o.text)).toEqual(['One', 'Two'])
})

test('a blank line may sit between the question and its options', async () => {
  const [q] = findAsked('[Question]: Which?\n\nOptions: 1. «One» 2. «Two»')
  expect(q.options.map(o => o.text)).toEqual(['One', 'Two'])
})

test('without guillemets, numbered or piped options still parse', async () => {
  expect(findAsked('[Question]: Ship?\nOptions: 1. Yes 2. No 3. Other')[0].options.map(o => o.text)).toEqual([
    'Yes',
    'No',
  ])
  expect(findAsked('[Question]: Ship?\nOptions: (Yes|No)')[0].options.map(o => o.text)).toEqual(['Yes', 'No'])
})

test('a question with no Options line is Yes/No', async () => {
  expect(findAsked('[Question]: Ship it?')).toEqual([yn('Ship it?')])
})

test('a list marker and bold around the tag are allowed', async () => {
  const parts = splitParts('1. **[Question]:** Ship it?\n- [Question]: Today?')
  expect(parts.flatMap(p => (p.kind === 'question' ? [[p.marker, p.text]] : []))).toEqual([
    ['1.', 'Ship it?'],
    ['-', 'Today?'],
  ])
})

test('a [Question]: inside a code block or a > quote is ignored', async () => {
  expect(findQuestions('```\n[Question]: x?\n```\n> [Question]: y?\n[Question]: z?')).toEqual(['z?'])
})

test('"Other team" is a real option, not the Other button', async () => {
  const [q] = findAsked('[Question]: Who?\nOptions: 1. «Our team» 2. «Other team» 3. «Other (type it)»')
  expect(q.options.map(o => o.text)).toEqual(['Our team', 'Other team'])
})

test('(pick any) makes the options multi-select; without options it stays Yes/No', async () => {
  const [multi] = findAsked('[Question]: Which ones? (pick any)\nOptions: 1. «One» 2. «Two»')
  expect(multi.multi).toBe(true)
  const [bare] = findAsked('[Question]: Which ones? (pick any)')
  expect(bare.multi).toBe(false)
})

test('a choice answer is sent as the option label', async () => {
  const q = findAsked('[Question]: Which first?\nOptions: 1. «Sync first» 2. «Backfill»')[0]
  const picks = [togglePick(q, null, { option: 0 })]
  expect(answersText({ questions: [q], picks })).toContain('1. Which first?\n   → 1. Sync first')
})

test('a one-of question swaps its pick, and a second press un-picks', async () => {
  const q = findAsked('[Question]: Which?\nOptions: 1. «One» 2. «Two»')[0]
  const a = togglePick(q, null, { option: 0 })
  const b = togglePick(q, a, { option: 1 })
  expect(b?.picked).toEqual([1])
  expect(togglePick(q, b, { option: 1 })).toBe(null)
})

test('a pick-any question toggles options independently and sends every pick', async () => {
  const q = findAsked('[Question]: Which? (pick any)\nOptions: 1. «One» 2. «Two» 3. «Three»')[0]
  let a = togglePick(q, null, { option: 2 })
  a = togglePick(q, a, { option: 0 })
  expect(a?.picked).toEqual([0, 2])
  expect(answersText({ questions: [q], picks: [a] })).toContain('→ 1. One; 3. Three')
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
  const q = findAsked('[Question]: Which? (pick any)\nOptions: 1. «One» 2. «Two»')[0]
  const a = setOther(q, togglePick(q, null, { option: 1 }), 'something else')
  expect(answersText({ questions: [q], picks: [a] })).toContain('→ 2. Two; Other: something else')
  expect(setOther(q, a, '')?.picked).toEqual([1])
  expect(setOther(yn('Ship it?'), setOther(yn('Ship it?'), null, 'x'), '  ')).toBe(null)
})

test('a reply can mix Yes/No and choice questions', async () => {
  const text = `[Question]: Ship it today?
[Question]: Which order?
Options: 1. «Sync first (Recommended)» 2. «Backfill first» 3. «Other»
[Question]: Anything to add? (pick any)
Options: 1. «Docs» 2. «Tests» 3. «Other»`
  const qs = findAsked(text)
  expect(qs.map(q => q.options.length)).toEqual([0, 2, 2])
  expect(qs.map(q => q.multi)).toEqual([false, false, true])
  const out = answersText({
    questions: qs,
    picks: [togglePick(qs[0], null, { yn: 'no' }), togglePick(qs[1], null, { option: 1 }), null],
  })
  expect(out).toContain('1. Ship it today?\n   → No')
  expect(out).toContain('2. Which order?\n   → 2. Backfill first')
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

test('a reply with one question gets buttons', async () => {
  expect(ownsMessage({ questions: [yn('Ready?')] }, [yn('Ready?')])).toBe(true)
})

test('a reply with no questions gets none', async () => {
  expect(ownsMessage({ questions: [] }, [])).toBe(false)
})

test('once the buttons are closed, no reply is drawn by the mod', async () => {
  expect(ownsMessage(null, [yn('Copy it?'), yn('Agreed?')])).toBe(false)
})

test('a later reply with different questions is not the open one', async () => {
  expect(ownsMessage({ questions: [yn('Copy it?'), yn('Agreed?')] }, [yn('Copy it?'), yn('Ship it?')])).toBe(false)
})

test('the same text with different options is not the open reply', async () => {
  const a = findAsked('[Question]: Which?\nOptions: 1. «One» 2. «Two»')
  const b = findAsked('[Question]: Which?\nOptions: 1. «One» 2. «Three»')
  expect(ownsMessage({ questions: a }, b)).toBe(false)
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
