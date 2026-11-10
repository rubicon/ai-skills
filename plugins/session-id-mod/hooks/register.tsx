import type { Register } from 'claude-code'

// Drawn in the style of Token Weather Usage's icons: outlined, rounded, softly filled, in a color deeper than the pill's tint.
const ICON_COLOR = '#3f7fd9'
const ICON_SIZE = 16
const COPY_ICON = `<svg xmlns="http://www.w3.org/2000/svg" width="${ICON_SIZE}" height="${ICON_SIZE}" viewBox="0 0 24 24"><rect x="8.5" y="8.5" width="12" height="12" rx="3" fill="${ICON_COLOR}" fill-opacity="0.16" stroke="${ICON_COLOR}" stroke-width="2"/><path d="M15.5 8.5V6.5A3 3 0 0 0 12.5 3.5h-6A3 3 0 0 0 3.5 6.5v6A3 3 0 0 0 6.5 15.5h2" fill="none" stroke="${ICON_COLOR}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`

const COVER_LABEL = '\u00a0'.repeat(200)

export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props.hasSurvey) return below

    // Read at every draw: /clear and resume go on under another id.
    const id = await $.session.id()
    const copy = async (press: { surface: string }) => {
      const { isCopied, reason } = await $.ui.copy({ text: id, surface: press.surface })
      $.ui.toast(isCopied ? 'Session ID copied' : `Could not copy the session ID (${reason})`)
    }

    if (e.surface === 'desktop') {
      const { Box, Button, Svg, Text } = $.ui.resolve(e)
      return (
        <Box flexDirection="column">
          {/* The keyed Box is the hover scope, so the card below shows while the pointer is over the pill. The pill inside it clips its cover Button, so that Button cannot stick out. */}
          <Box key="session-id" flexDirection="row" alignSelf="flex-start" flexShrink={0} marginLeft={1} marginY={1}>
            {/* The pill's tint and outline are the context pill's in Token Weather Usage. */}
            <Box
              flexDirection="row"
              alignItems="center"
              flexShrink={0}
              columnGap={1}
              paddingX={1}
              paddingY={0}
              overflow="hidden"
              borderStyle="round"
              borderColor="rgba(47,104,192,0.28)"
              backgroundColor="rgba(47,104,192,0.10)"
            >
              {/* The desktop draws a Button as a native control that flattens its text's styling and sizes it to its label, and a Button cannot hold an Svg. So the label, the id and the icon are plain elements, and one Button lies over the whole pill to take the press. Its label is many non-breaking spaces, wider than any pill: invisible, and clipped by the pill. */}
              <Text weight="semibold">Session ID:</Text>
              <Text italic mono>{id}</Text>
              <Svg key="icon" source={COPY_ICON} alt="Copy session ID" width={ICON_SIZE} height={ICON_SIZE} />
              <Box position="absolute" top={0} left={0} right={0} bottom={0}>
                <Button key="copy" plain onPress={copy}>{COVER_LABEL}</Button>
              </Box>
            </Box>
            {/* No key: a keyed Box scopes its own hover, and a hidden one is never hovered. Absolute, so showing it moves nothing. */}
            <Box
              position="absolute"
              bottom={1}
              left={0}
              display="none"
              hover={{ display: 'flex' }}
              flexDirection="column"
              paddingX={1}
              paddingY={0}
              borderStyle="round"
              borderColor="subtle"
              backgroundColor="background"
            >
              <Text dimColor>Click to copy</Text>
            </Box>
          </Box>
          {below}
        </Box>
      )
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        <Box key="session-id" flexDirection="row" alignItems="center" alignSelf="flex-start" flexShrink={0} marginLeft={1}>
          <Button key="copy" plain onPress={copy}>
            <Text weight="semibold">Session ID:</Text> <Text>{id}</Text>
          </Button>
          {/* No key: a keyed Box scopes its own hover, and a hidden one is never hovered. Absolute, so showing it moves nothing. */}
          <Box
            position="absolute"
            bottom={1}
            left={0}
            display="none"
            hover={{ display: 'flex' }}
            flexDirection="column"
            paddingX={1}
            paddingY={0}
            borderStyle="round"
            borderColor="subtle"
            backgroundColor="background"
          >
            <Text dimColor>Click to copy</Text>
          </Box>
        </Box>
        {below}
      </Box>
    )
  })
}
