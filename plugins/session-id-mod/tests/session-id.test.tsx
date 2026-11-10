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

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    await ui.press({ key: 'copy' })
    await ui.unmount()
  }

  expect(copied).toEqual(['abc-123', 'abc-123'])
})

type Node = {
  type?: string
  key?: string
  props?: Record<string, unknown> & { weight?: string; bold?: boolean; key?: string }
  children?: Array<Node | string>
}

function walk(node: Node | string, visit: (node: Node, ancestors: Node[]) => void, ancestors: Node[] = []) {
  if (typeof node === 'string') return
  visit(node, ancestors)
  for (const child of node.children ?? []) walk(child, visit, [...ancestors, node])
}

// Every string in the tree in document order, with the Text that holds it and the elements around it.
function runs(root: Node) {
  const found: Array<{ text: string; holder: Node; ancestors: Node[] }> = []
  const visit = (node: Node, ancestors: Node[]) => {
    for (const child of node.children ?? []) {
      if (typeof child !== 'string') visit(child, [...ancestors, node])
      else if (child.trim() !== '') found.push({ text: child, holder: node, ancestors })
    }
  }
  visit(root, [])
  return found
}

const isSemibold = (node: Node) => node.props?.weight === 'semibold'

type Kit = Parameters<Parameters<typeof test>[1]>
type Surface = 'terminal' | 'desktop'

// The hooks beneath the mod register before the first mount, once per test.
function seed(on: Kit[1]) {
  on('session.id', () => ({ value: 'abc-123' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
}

async function pillTree($: Kit[0], surface: Surface) {
  const ui = await $.ui.mount({ ...BAND, surface })
  const tree = (await ui.drawn()) as unknown as Node
  await ui.unmount()
  return tree
}

test('the label is semibold and the id is not, on every surface', async ($, on) => {
  seed(on)
  for (const surface of ['terminal', 'desktop'] as const) {
    const [label, id] = runs(await pillTree($, surface))
    expect(label.text).toBe('Session ID:')
    expect(isSemibold(label.holder)).toBe(true)
    expect(id.text).toBe('abc-123')
    expect(isSemibold(id.holder)).toBe(false)
  }
})

test('on desktop the label and the id are drawn outside any Button, so their styling survives', async ($, on) => {
  seed(on)
  const [label, id] = runs(await pillTree($, 'desktop'))

  expect(label.ancestors.some(node => node.type === 'Button')).toBe(false)
  expect(id.ancestors.some(node => node.type === 'Button')).toBe(false)
})

test('on desktop the id is italic in a monospaced face', async ($, on) => {
  seed(on)
  const [, id] = runs(await pillTree($, 'desktop'))

  expect(id.holder.props?.italic).toBe(true)
  expect(id.holder.props?.mono).toBe(true)
})

test('on desktop the pill ends in a copy icon', async ($, on) => {
  seed(on)
  const tree = await pillTree($, 'desktop')
  const svgs: Node[] = []
  walk(tree, node => {
    if (node.type === 'Svg') svgs.push(node)
  })

  expect(svgs).toHaveLength(1)
  expect(svgs[0].props?.alt).toBe('Copy session ID')
  expect(String(svgs[0].props?.source)).toContain('<svg')
})

test('on desktop one Button with a pill-wide label lies over the pill, and the pill clips it', async ($, on) => {
  seed(on)
  const tree = await pillTree($, 'desktop')
  const buttons: Array<{ node: Node; ancestors: Node[] }> = []
  walk(tree, (node, ancestors) => {
    if (node.type === 'Button') buttons.push({ node, ancestors })
  })

  expect(buttons).toHaveLength(1)
  const { node: button, ancestors } = buttons[0]
  expect(button.props?.key).toBe('copy')

  // A desktop Button is sized to its label and ignores the Box around it, so the label is
  // many non-breaking spaces: wider than any pill, invisible, and clipped by the pill.
  const label = button.props?.label ?? button.children?.[0]
  expect(typeof label).toBe('string')
  expect(String(label)).toMatch(/^\u00a0{200}$/)

  const cover = ancestors[ancestors.length - 1]
  expect(cover.props?.position).toBe('absolute')
  // It reaches past the pill's right edge so that the "..." the desktop draws where it cuts the label off falls outside the clip.
  expect([cover.props?.top, cover.props?.left, cover.props?.right, cover.props?.bottom]).toEqual([0, 0, -4, 0])

  const pill = ancestors[ancestors.length - 2]
  expect(pill.props?.overflow).toBe('hidden')
  expect(pill.props?.borderStyle).toBe('round')
})

test('the pill is inset from the left edge and spaced from its neighbours on desktop', async ($, on) => {
  seed(on)
  const tree = await pillTree($, 'desktop')
  let pill: Node | undefined
  walk(tree, node => {
    if (node.props?.key === 'session-id' || node.key === 'session-id') pill = node
  })

  expect(pill?.props?.marginLeft).toBe(1)
  expect(pill?.props?.marginY).toBe(1)
})

test('on the terminal the label and the id sit inside the one Button', async ($, on) => {
  seed(on)
  const [label, id] = runs(await pillTree($, 'terminal'))

  expect(label.ancestors.some(node => node.type === 'Button')).toBe(true)
  expect(id.ancestors.some(node => node.type === 'Button')).toBe(true)
})

test('the hover card holds only the copy hint, not a second copy of the id', async ($, on) => {
  seed(on)
  const texts = runs(await pillTree($, 'desktop')).map(run => run.text)

  expect(texts.filter(text => text.includes('abc-123'))).toHaveLength(1)
  expect(texts).toContain('Click to copy')
})
