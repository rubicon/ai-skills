import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'session-id-mod',
  component: 'AbovePrompt',
  props: { hasSurvey: false, bodyColumns: 80 },
} as const

test('the icon is drawn with the session id, on every surface', async ($, on) => {
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

test('pressing the icon copies the session id', async ($, on) => {
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
