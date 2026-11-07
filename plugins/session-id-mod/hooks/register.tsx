import type { Register } from 'claude-code'

export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props.hasSurvey) return below

    // Read at every draw: /clear and resume go on under another id.
    const id = await $.session.id()
    const { Box, Button, Text } = $.ui.resolve(e)
    const isDesktop = e.surface === 'desktop'

    return (
      <Box flexDirection="column">
        {/* The pill's tint and outline are the context pill's in Token Weather Usage. A keyed Box is the hover scope: the card below shows while the pointer is over it. */}
        <Box
          key="session-id"
          flexDirection="row"
          alignItems="center"
          alignSelf="flex-start"
          flexShrink={0}
          paddingX={0}
          paddingY={0}
          borderStyle={isDesktop ? 'round' : undefined}
          borderColor={isDesktop ? 'rgba(47,104,192,0.28)' : undefined}
          backgroundColor={isDesktop ? 'rgba(47,104,192,0.10)' : undefined}
        >
          <Button
            key="copy"
            plain
            onPress={async press => {
              const { isCopied, reason } = await $.ui.copy({ text: id, surface: press.surface })
              $.ui.toast(isCopied ? 'Session ID copied' : `Could not copy the session ID (${reason})`)
            }}
          >
            <Text size="title" color="#ffffff">#</Text>
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
            <Text>{id}</Text>
            <Text dimColor>Click the icon to copy</Text>
          </Box>
        </Box>
        {below}
      </Box>
    )
  })
}
