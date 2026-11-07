import type { Register } from 'claude-code'

export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props.hasSurvey) return below

    // Read at every draw: /clear and resume go on under another id.
    const id = await $.session.id()
    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {/* The keyed Box is the hover scope: the id is drawn only while the pointer is over it. */}
        <Box key="session-id" flexDirection="row" gap={1}>
          <Button
            key="copy"
            label="⧉"
            plain
            onPress={async press => {
              const { isCopied, reason } = await $.ui.copy({ text: id, surface: press.surface })
              $.ui.toast(isCopied ? 'Session ID copied' : `Could not copy the session ID (${reason})`)
            }}
          />
          <Box display="none" hover={{ display: 'flex' }}>
            <Text dimColor>{id} · click to copy</Text>
          </Box>
        </Box>
        {below}
      </Box>
    )
  })
}
