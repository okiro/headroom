<p align="center">
  <img src="macos-app/Headroom/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="Headroom icon">
</p>

<h1 align="center">Headroom</h1>

<p align="center">
  <b>Your Claude Code limits and spending, always one glance away in the menu bar.</b>
</p>

<p align="center">
  <a href="https://github.com/okiro/headroom/releases/latest/download/Headroom.dmg">
    <img src="https://img.shields.io/badge/Download_for_macOS-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="44">
  </a>
  <br>
  <sub>Free · macOS 14 Sonoma or later · Apple silicon and Intel</sub>
</p>

---

You're deep in a Claude Code session when it stops: you've hit your 5-hour limit, with no warning. Or you wonder how much this month's work would have cost at API prices, and there's no easy way to find out.

Headroom sits in your menu bar and answers both. It shows how much of your limit is used and when it resets, plus what your Claude Code usage costs.

## Features

- **Limit at a glance.** A little robot head in the menu bar fills up as you use your 5-hour limit, next to the percentage. When its antenna lights up, you have no headroom left.
- **5-hour and 7-day limits.** Bars with countdowns to the next reset, the tokens you've used in each window, and overage when you're past the limit.
- **What it costs.** Today, this month and all time, priced per model at API rates.
- **Projects.** Your most recent projects and your most expensive ones, with tokens and cost for each.
- **Peak hours.** See when peak hours are on and how long until they end.
- **Keeps your history.** Usage is saved as it's read, so your totals survive even after Claude Code deletes old sessions.
- **Updates itself.** New versions install quietly in the background.

## Get started

1. **[Download Headroom](https://github.com/okiro/headroom/releases/latest/download/Headroom.dmg)**, open the `.dmg` and drag the app into **Applications**.
2. Open it. A robot head appears in your menu bar.
3. Click it and press **Connect to Claude Code** to show your usage limits. Costs and projects show up without connecting.

Click the robot for the dashboard; right-click for **Refresh**, **Check for Updates…**, **Update Automatically** and **Quit**.

## Questions

<details>
<summary><b>What do I need?</b></summary>
<br>
Claude Code, installed and logged in on this Mac. The app reads your usage from Claude Code's local session files and your login from the macOS keychain.
</details>

<details>
<summary><b>What does "Connect" do?</b></summary>
<br>
It reads Claude Code's login from your keychain and keeps it in memory only, never on disk. Every 15 minutes the app uses it to make a tiny API request, which reports how much of your limits is used. Disconnect any time from the dashboard.
</details>

<details>
<summary><b>Are the costs what I actually pay?</b></summary>
<br>
They're what your usage would cost at Anthropic's API prices. On a Pro or Max plan you pay your subscription, not this amount.
</details>

<details>
<summary><b>Does it collect any data?</b></summary>
<br>
No. It only connects to Anthropic's API, for your usage limits, and to GitHub, once a day, to check for updates.
</details>

<details>
<summary><b>How do I uninstall it?</b></summary>
<br>
Right-click the robot, choose <b>Quit</b>, and drag the app from Applications to the Trash. Its saved history is in <code>~/Library/Application Support/Headroom/</code>.
</details>

---

<sub>Want to build it yourself or see how it works? Head to <a href="DEVELOPMENT.md">DEVELOPMENT.md</a>.</sub>
