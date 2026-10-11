# Work Summary

~3 days of work writing documentation and experimenting with different agent orchestration tools like gas town. The most effective one ended up just being Claude Opus with `/goal` and subagents since it is cross platform, and gas town isn't really.

For the first couple days, I needed about an hour a day to make corrections to the agents. For example, the agents wanted to run a full 30 min test suite for every commit. This was making them too slow. I had to clean that up. They also kept stopping for various reasons, which was annoying. (I was using Claude Sonnet). I was running in Hermes agent and it would sometimes determine that the goal was impossible since there was a task assigned to humans. After the first couple days, I switch to Claude Opus 5.5, which can autonomously handle all the tasks.


Other thoughts:

Worktree pollution: Each bead spawns a whole new worktree and it doesn't cleanup very well, so after a couple days I ended up with a 300GB directory of stale worktrees. A better solution here is for there to be multiple workers each with their own worktree, doing one bead at a time. Then, git town append <bead> to create a new branch, which would allow for more efficient merging.

Agent healthiness: Tools like gas town know how to restart an agent if it ever gets stuck. That would be extremely useful here.


Spider JS to QuickJS-ng: Likely, there were some expansions broken by this change. Claude said at least two expansions used spidermonkey specific JS, but I didn't investigate it at all.

Additional things claude forgot:

After a few days of compactions:

- Claude forgot that it was supposed to parallelize tasks.
- Claude forgot that it could exercise judgement on human beads if it was otherwise completely blocked.
- Claude forgot it was supposed to be autonomous and started prompting me for input again.
- Claude, even on opus 5.5, stopped working a couple times even though it's goal was to complete all tasks in the beads queue.
- Claude started making separate commits for beads logs.

Other flaws: Ideally, there would be a reviewer the makes sure beads are done before doing a pull request. Instead, a number of follow up beads have been created, which is good, but wasn't necessarily needed.

Overall learning: It would be great to have programmatic scheduling of agents such as merge workers, reviewers, and health checks to make sure the agent keeps running. These are in gas town, but not my custom setup, so my agents often stop working.


10/7 Notes - Claudes was running ~250 background tasks, kill CPU. I really like the gastown design where there is a fixed number of worker agents, a refinery, and the mayor and the mailbox. It controls for stuff like this a little better since a lot of those tasks were essentially for message passing. Oolite does run on Ubuntu, so I could have used gas town to work through the tasks, which would have made a lot more sense.

```
# List queue for current rig
gt mq list
```

I tried to get Claude to start doing more things in parallel, which is the cause of this to get work done faster. It did spin more up in parallel, but without tools like the gt merge queue, it isn't smart about resource usage.

Overall, I'm pretty impressed with how much work Claude is able to do autonomously here and keep everything working.
