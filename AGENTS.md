# Agent Guidelines

- Add sufficient logging around important control flow, external process calls, network operations, configuration loading, and error handling paths.
- Logs should make failures easy to debug: include the operation being attempted, relevant non-sensitive context, success/failure outcomes, and the error returned by the system.
- Do not log secrets, passwords, tokens, private keys, or full proxy credentials. Mask sensitive values when context is necessary.
