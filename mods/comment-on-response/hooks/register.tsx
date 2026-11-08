import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Pending } from '../types'

const PANE = 'comment-on-response'
const HEADER = 'See my comments on your response.'
const pending = atom<Pending | null>(
  { plugin: 'comment-on-response', key: 'pending' } as const,
  null,
  { shape: 'pending-1' },
)

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'comment',
      description: 'Comment on the text you selected in a response',
    })
    return next(e)
  })

  on('command.run', { command: 'comment' }, async $ => {
    const picked = await $.ui.selection()
    if (!picked || !picked.text.trim()) {
      return { text: 'Select text in a response first, then run /comment.' }
    }
    await update($, pending, () => ({ quote: picked.text.trim(), comment: '' }))
    await $.ui.open({ id: PANE, title: 'Add comment', focus: true })
    return { text: 'Type your comment in the pane and press Enter (or Add).' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Input, Button } = $.ui.resolve(e)
    const cur = await read($, pending)
    if (!cur) return <Text dimColor>Select text, then run /comment.</Text>

    const add = async (comment: string) => {
      if (!comment.trim()) return
      const box = await $.prompt.read()
      const head = box.text.startsWith(HEADER) ? '' : `${HEADER}\n\n`
      const quote = cur.quote.split('\n').map(l => `> ${l}`).join('\n')
      await $.prompt.fill({
        text: `${head}${quote}\n${comment.trim()}\n\n`,
        mode: 'append',
      })
      await update($, pending, () => null)
      await $.ui.close({ id: PANE })
    }

    return (
      <Box flexDirection="column">
        <Text dimColor>Selected:</Text>
        <Text>{cur.quote.slice(0, 600)}</Text>
        <Input
          key="comment"
          label="Comment: "
          rows={3}
          autoFocus
          submitLabel="add"
          value={cur.comment}
          onInput={v => void update($, pending, p => (p ? { ...p, comment: v } : p))}
          onSubmit={v => void add(v)}
        />
        <Button key="add" variant="primary" onPress={() => void add(cur.comment)}>
          Add
        </Button>
      </Box>
    )
  })
}
