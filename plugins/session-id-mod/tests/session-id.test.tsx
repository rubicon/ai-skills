import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'session-id-mod',
  component: 'AbovePrompt',
  props: { hasSurvey: false, bodyColumns: 80 },
} as const

test('the pill is drawn with the session id, on every surface', async ($, on) => {
  on('session.id', () => ({ value: 'abc-123' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })

    expect(await ui.find({ type: 'Button', key: 'copy' })).toBeDefined()
    expect((await ui.find({ type: 'Text', text: /abc-123/ }))?.text).toContain('abc-123')
    await ui.unmount()
  }
})

test('pressing the pill copies the session id alone, not the label', async ($, on) => {
  const copied: string[] = []
  on('session.id', () => ({ value: 'abc-123' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  on('ui.copy', (_, e) => {
    copied.push(e.text)
    return { value: { isCopied: true } }
  })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await ui.press({ key: 'copy' })

  expect(copied).toEqual(['abc-123'])
  await ui.unmount()
})

type Node = { type?: string; props?: { weight?: string; bold?: boolean }; children?: Array<Node | string> }

// Every string in the tree, with whether a bold Text encloses it.
function runs(node: Node | string, bold = false): Array<{ text: string; bold: boolean }> {
  if (typeof node === 'string') return [{ text: node, bold }]
  const isBold = bold || node.props?.weight === 'bold' || node.props?.bold === true
  return (node.children ?? []).flatMap(child => runs(child, isBold))
}

test('the pill reads "Session ID: <id>" with only the label bold, on every surface', async ($, on) => {
  on('session.id', () => ({ value: 'abc-123' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    const button = (await ui.find({ type: 'Button', key: 'copy' })) as unknown as Node
    const drawn = await ui.drawn()
    const pill = runs(drawn as unknown as Node).filter(run => run.text.trim() !== '')

    expect(button).toBeDefined()
    expect(pill.slice(0, 2)).toEqual([
      { text: 'Session ID:', bold: true },
      { text: 'abc-123', bold: false },
    ])
    await ui.unmount()
  }
})

test('the hover card holds only the copy hint, not a second copy of the id', async ($, on) => {
  on('session.id', () => ({ value: 'abc-123' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  const texts = runs((await ui.drawn()) as unknown as Node).map(run => run.text)

  expect(texts.filter(text => text.includes('abc-123'))).toHaveLength(1)
  expect(texts).toContain('Click to copy')
  await ui.unmount()
})
