import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Pending, YesNo } from '../types'
import {
  addSheet,
  answersText,
  findAsked,
  hasAnswers,
  sameQuestions,
  setOther,
  sheetFor,
  splitParts,
  togglePick,
  withAnswers,
} from './questions'

const legacy = atom({ plugin: 'answer-buttons', key: 'pending' } as const, null)
const open = atom({ plugin: 'answer-buttons', key: 'open' } as const, [])

// Options longer than this many characters are drawn as a number button with wrapping text beside it.
const LONG_OPTION = 60

// Every reply's questions stay open until they are answered or dismissed, or a later reply says
// it replaces them; a new reply without questions closes nothing.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    // Carry over the one sheet an earlier version kept.
    const old = await read($, legacy)
    if (old !== null) {
      await update($, open, sheets => addSheet(sheets, old, false))
      await update($, legacy, () => null)
    }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined && e.reason === 'answer') {
      const questions = findAsked(e.answer)
      if (questions.length >= 1) {
        const sheet: Pending = { questions, picks: questions.map(() => null), typing: null }
        const replaces = /\(replaces earlier questions\)/i.test(e.answer)
        await update($, open, sheets => addSheet(sheets, sheet, replaces))
      }
    }

    return next(e)
  })

  // Answered sheets ride along, visibly, with the next prompt the person types and then close.
  // Sheets with nothing picked stay open.
  on('prompt.submit', async ($, e, next) => {
    const sheets = await read($, open)
    const answered = sheets.filter(s => hasAnswers(s))
    if (answered.length === 0) {
      return next(e)
    }

    await update($, open, all => all.filter(s => !hasAnswers(s)))
    return next({ ...e, text: `${e.text}\n\n${answered.map(answersText).join('\n\n')}` })
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.props.isSummary) {
      return next(e)
    }

    const questions = findAsked(e.props.text)
    const sheets = await read($, open)
    const sheet = sheetFor(sheets, questions)

    // Only a reply whose questions are open is ours; every other reply draws as normal.
    if (sheet === null) {
      return next(e)
    }

    const parts = splitParts(e.props.text)
    const ui = $.ui.resolve(e)
    const { Box, Text, Button, Markdown } = ui
    // Not every surface has a text box; there the Other button only toggles.
    const Input = 'Input' in ui ? ui.Input : null

    // Every change goes to this reply's sheet alone.
    const change = (fn: (p: Pending) => Pending | null) =>
      update($, open, all =>
        all.flatMap(s => {
          if (!sameQuestions(s.questions, questions)) return [s]
          const changed = fn(s)
          return changed === null ? [] : [changed]
        }),
      )

    // Pressing a picked button again un-picks it.
    const press = (i: number, what: { yn: YesNo } | { option: number }) =>
      change(p => ({
        ...p,
        picks: p.picks.map((old, j) => (j !== i ? old : togglePick(p.questions[i]!, old, what))),
        typing: p.typing === i && !p.questions[i]!.multi ? null : p.typing,
      }))

    // The Other box opens on a press; pressing again closes it and clears what was typed.
    const toggleOther = (i: number) =>
      change(p =>
        p.typing !== i
          ? { ...p, typing: i }
          : {
              ...p,
              typing: null,
              picks: p.picks.map((old, j) => (j !== i ? old : setOther(p.questions[i]!, old, ''))),
            },
      )

    const saveOther = (i: number, text: string) =>
      change(p => ({
        ...p,
        typing: null,
        picks: p.picks.map((old, j) => (j !== i ? old : setOther(p.questions[i]!, old, text))),
      }))

    // Sends this reply's answers at once. Button has no disabled prop, so with nothing answered a
    // press does nothing.
    const submit = async () => {
      const current = sheetFor(await read($, open), questions)
      if (current === null || !hasAnswers(current)) return

      // Closed first: a second press finds nothing, and the buttons go away.
      await change(() => null)

      // A typed draft goes in front. It is cleared before sending so it is not sent twice;
      // if it cannot be cleared, it stays in the box and is left out of the message.
      const { text: draft } = await $.prompt.read()
      let typed = ''
      if (draft.trim() !== '') {
        const { isFilled } = await $.prompt.fill({ text: '', mode: 'replace' })
        if (isFilled) typed = draft
      }

      // A plugin's own submit skips its own prompt.submit hook, so the answers are sent here.
      await $.prompt.submit({ text: withAnswers(typed, answersText(current)), asUser: true })
    }

    const answered = sheet.picks.filter(pick => pick !== null).length

    let q = -1

    return (
      <Box flexDirection="column">
        {parts.map((part, i) => {
          if (part.kind === 'text') {
            return <Markdown key={`t${i}`} text={part.text} />
          }

          q += 1
          const n = q
          const picked = sheet.picks[n]
          const hasOther = picked?.other != null
          const otherButton = (
            <Button
              key={`other-${n}`}
              label={hasOther ? 'Other ✓' : 'Other'}
              variant={hasOther ? 'primary' : undefined}
              onPress={() => toggleOther(n)}
            />
          )

          return (
            <Box key={`q${i}`} flexDirection="column" marginBottom={1}>
              <Text>
                {part.marker === '' ? '' : `${part.marker} `}
                <Text underline>{part.text}</Text>
              </Text>
              {part.options.length === 0 ? (
                <Box flexDirection="row" gap={1}>
                  <Button
                    key={`yes-${n}`}
                    label={picked?.choice === 'yes' ? 'Yes ✓' : 'Yes'}
                    variant={picked?.choice === 'yes' ? 'primary' : undefined}
                    onPress={() => press(n, { yn: 'yes' })}
                  />
                  <Button
                    key={`no-${n}`}
                    label={picked?.choice === 'no' ? 'No ✓' : 'No'}
                    variant={picked?.choice === 'no' ? 'primary' : undefined}
                    onPress={() => press(n, { yn: 'no' })}
                  />
                  {otherButton}
                </Box>
              ) : (
                <Box flexDirection="column">
                  {part.options.map((option, k) => {
                    const chosen = picked?.picked.includes(k) ?? false
                    // A button label never wraps, so a long option would push the reply sideways
                    // into a scrollbar. Its button carries just the number; the words wrap beside it.
                    if (option.text.length > LONG_OPTION) {
                      return (
                        <Box key={`optrow-${n}-${k}`} flexDirection="row" gap={1}>
                          <Button
                            key={`opt-${n}-${k}`}
                            label={`${k + 1}${chosen ? ' ✓' : ''}`}
                            variant={chosen ? 'primary' : undefined}
                            onPress={() => press(n, { option: k })}
                          />
                          <Box flexShrink={1} flexGrow={1}>
                            <Text wrap="wrap">
                              {option.text}
                              {option.recommended ? ' (Recommended)' : ''}
                            </Text>
                          </Box>
                        </Box>
                      )
                    }
                    return (
                      <Button
                        key={`opt-${n}-${k}`}
                        label={`${option.label}${option.recommended ? ' (Recommended)' : ''}${chosen ? ' ✓' : ''}`}
                        variant={chosen ? 'primary' : undefined}
                        onPress={() => press(n, { option: k })}
                      />
                    )
                  })}
                  {otherButton}
                </Box>
              )}
              {sheet.typing === n && Input !== null ? (
                <Input
                  key={`input-${n}`}
                  label="Other:"
                  placeholder="type your answer"
                  value={picked?.other ?? ''}
                  submitLabel="save"
                  onSubmit={(text: string) => saveOther(n, text)}
                />
              ) : null}
            </Box>
          )
        })}
        <Box flexDirection="row" gap={1}>
          <Text dimColor>
            {answered} of {questions.length} answered. Press Submit, or type a message and the answers go
            with it. Unanswered questions stay open.
          </Text>
          <Button key="submit" label="Submit" variant="primary" onPress={() => void submit()} />
          <Button key="dismiss" label="Dismiss" onPress={() => void change(() => null)} />
        </Box>
      </Box>
    )
  })
}
