# Upstream issue for DankMaterialShell (draft)

Goal: let plugins register their own DankDash tab without patching core files.
If this lands, the BitcoinFeed plugin's delta against upstream drops from 22
lines to zero.

Repo: https://github.com/AvengeMedia/DankMaterialShell
Tested against: dms-shell 1.5.3-1 ("The Wolverine")

---

## Title

Allow plugins to register DankDash tabs

## Body

### What I'm trying to do

I wrote a plugin that renders a Bitcoin mempool view. It works as a bar widget
and as a desktop widget through the normal plugin API. What it cannot do is add
itself as a tab in the DankDash popout, which is where a full-size view of this
kind actually belongs.

### Why it doesn't work today

The set of dash tabs is a hardcoded whitelist in `Common/SettingsData.qml`:

```qml
readonly property var _dashTabIds: ["overview", "media", "wallpaper", "weather", "settings"]
```

It is not just a default list — it is used as a filter, so an unknown id is
actively dropped when the stored tab order is read back:

```qml
if (_dashTabIds.indexOf(id) < 0 || seen[id])
    continue;
```

`Modules/DankDash/DankDashPopout.qml` holds a parallel hardcoded map of
id → icon/label, plus the loader chain that decides which component to show,
and `DMSShellIPC.qml` has its own switch for addressing a tab over IPC.

So adding one tab means editing three core files. That is what my local
installation does today, and it is the entire delta I carry against upstream —
22 lines, none of which do anything except announce that a tab exists:

| File | Changed lines | What the change does |
|---|---|---|
| `Common/SettingsData.qml` | 2 | add the id to the whitelist |
| `DMSShellIPC.qml` | 2 | add an IPC case for the id |
| `Modules/DankDash/DankDashPopout.qml` | 18 | icon + label entry, a `Loader`, and two height/item lookups |

Because those lines sit inside files that get refactored regularly, a plugin
distributed this way would break on most releases — which effectively means a
plugin cannot ship a dash tab at all.

### What I'd suggest

Let a plugin declare a dash-tab surface in `plugin.json`, the same way it
already declares `bar` or `desktop` surfaces:

```json
{
  "id": "bitcoinFeed",
  "type": "composite",
  "capabilities": ["daemon", "dankbar-widget", "desktop-widget", "dash-tab"],
  "components": {
    "daemon": "./BitcoinFeedDaemon.qml",
    "widget": "./BitcoinFeedWidget.qml",
    "desktop": "./BitcoinFeedDesktop.qml",
    "dashTab": "./BitcoinTab.qml"
  },
  "icon": "currency_bitcoin"
}
```

and have the three places above consult the registered plugin tabs in addition
to the built-in ones:

- `_dashTabIds` becomes built-ins plus ids of loaded plugins that declare
  `dash-tab`, so the filter stops dropping them
- `DankDashPopout.qml` falls back to the plugin's `icon` and `name` when an id
  is not in the built-in map, and loads the declared component
- the IPC switch resolves unknown ids against the same registry

Tab order and enable/disable would keep working unchanged, since both already
operate on a list of ids.

### Notes

- I'm happy to open a PR if the approach sounds right — I'd rather agree on the
  shape first than send an unsolicited refactor of the dash.
- The height handling in `DankDashPopout.qml` is the only part that isn't
  purely mechanical: built-in tabs report an `implicitHeight` and the popout
  reads it per id. A plugin tab would need the same contract, presumably just
  `implicitHeight` on the loaded component.

---

## To settle before sending

- Account: the issue should come from the new account, not the existing one.
- Attach a screenshot of the Bitcoin tab -- it shows the point immediately.
- Check whether such an issue already exists (search: "dash tab plugin",
  "custom dash tab").
