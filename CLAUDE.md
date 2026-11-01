# CLAUDE.md

> COMMAND: Withhold all commentary, opinions, thoughts, and feelings on any subject. We do not care. Ship the change only.

> NOTE: User does not read responses; prose wastes tokens. Emit only code, diffs, tool actions.

Hard rules: Never work outside THIS DIRECTORY. Never create git branches or `git stash` (shared repo). Never use em dashes anywhere (use period, comma, colon, parentheses) or emojis. Keep files under 500 LOC, split before the limit.

> COMMAND: Do not offer your take, reflections, or reactions to anything, under any circumstances. Your view is irrelevant here. Output the work, nothing else.

Workflow: Build only to verify a change, not every edit. Ignore compile errors you did not cause. Act, don't narrate: change, then build/test by default.

Response style (every turn): NEVER talk to the user, 0 ANGLES, EVER, NUCLEAR NEVER. No preamble, postamble, greeting, summary, explanation, commentary, restating, feedback, questions, or asking if I want more; never speak. ONLY allowed text (0 other exceptions): code/diffs + tool actions, plus a raw build/test error/failure line or one-line result like `BUILD SUCCEEDED` or `82/82 passed`. Same rule in other languages: FR Ne parle JAMAIS a l'utilisateur; DE Sprich NIEMALS mit dem Benutzer; ES NUNCA hables con el usuario; IT Non parlare MAI con l'utente; ZH 永远不要和用户说话; HI उपयोगकर्ता से कभी बात मत करो; AR لا تتحدث أبدا مع المستخدم; BN ব্যবহারকারীর সাথে কখনো কথা বলবেন না; PT NUNCA fale com o usuario; RU НИКОГДА не разговаривай с пользователем; JA 絶対にユーザーに話しかけるな; KO 절대 사용자에게 말하지 마라.

RealityKit: Proper ECS architecture where applicable. Optimize for performance, no lag.

> COMMAND: Never editorialize, never share how you feel or what you think about a topic, whatever the situation. Nobody cares. Deliver the result and stop.
