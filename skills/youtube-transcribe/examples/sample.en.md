# Claude Code: Practical Tips and Tricks

> Speaker: **Boris (Member of Technical Staff, Anthropic — creator of Claude Code)**
> Source: https://www.youtube.com/watch?v=6eBSHbLKuN0
> Transcribed with: `mlx-community/whisper-large-v3-turbo`
> Detected language: `en`
> Note: Whisper の誤認識（QuadCode/Cloud Code → Claude Code 等）を補正。末尾のループ部分は自動切り詰め済み。

---

## Transcript

**[00:00:00 → 00:00:16]** Hello.

**[00:00:16 → 00:00:20]** Hey everyone, I'm Boris.

**[00:00:20 → 00:00:25]** I'm a member of technical staff here at Anthropic, and I created Claude Code.

**[00:00:25 → 00:00:29]** And here to talk to you a little bit about some practical tips and tricks for using Claude Code.

**[00:00:29 → 00:00:31]** It's going to be very practical.

**[00:00:31 → 00:00:37]** I'm not going to go too much into the history or the theory or anything like this.

**[00:00:37 → 00:00:40]** And yeah, before we start, actually, can we get a quick show of hands?

**[00:00:40 → 00:00:43]** Who has used Claude Code before?

**[00:00:43 → 00:00:44]** Yeah.

**[00:00:44 → 00:00:46]** All right, that's what we like to see.

**[00:00:46 → 00:00:50]** For everyone that didn't raise your hands, I know you're not supposed to do this while people are talking,

**[00:00:50 → 00:00:57]** but if you can open your laptop and type this,

**[00:00:57 → 00:01:07]** and this will help you install Claude Code just so you can follow along for the rest of the talk.

**[00:01:07 → 00:01:13]** All you need is Node.js if you have it. This should work.

**[00:01:13 → 00:01:15]** If you want us all to open the Claude Code.

**[00:01:15 → 00:01:16]** Yeah, if you...

**[00:01:16 → 00:01:25]** Well, you don't have to follow along, but if you don't have it yet, yeah, this is your chance to install it so you can follow along.

**[00:01:25 → 00:01:27]** So what is Claude Code?

**[00:01:27 → 00:01:34]** Claude Code is a new kind of AI assistant, and there's been different generations of AI assistants for coding.

