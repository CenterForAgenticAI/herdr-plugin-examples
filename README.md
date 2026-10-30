# Herdr plugin examples

Example plugins for [Herdr](https://github.com/herdrdev/herdr). Each plugin lives in its own directory and installs with GitHub shorthand:

```bash
herdr plugin install CenterForAgenticAI/herdr-plugin-examples/<plugin>
```

| Plugin | What it shows | Needs |
| --- | --- | --- |
| [agent-board](agent-board/) | A desktop region on the right edge or bottom that lists every agent and its status; press a number to jump to it. | A Herdr build with desktop regions ([`feat/desktop-regions-v2`](https://github.com/CenterForAgenticAI/herdr/tree/feat/desktop-regions-v2)), `bash`, `jq` |

Desktop regions are a proposed Herdr feature and are not in a Herdr release yet.

## License

MIT. See [LICENSE](LICENSE).
