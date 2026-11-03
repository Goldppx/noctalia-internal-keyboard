# Noctalia Internal Keyboard

[Noctalia](https://noctalia.dev) v5 插件：[`internal-keyboard`](internal-keyboard/README.md) ——
把笔记本内置键盘在图形会话里关掉（用外接键盘时），随时再打开。控制中心磁贴一键切换、可选的栏挂件、
切换时的 OSD 提示，关闭状态按需持久化到下次开机前。

关键点：**只关 libinput 这一层**，内核照样把按键喂给 TTY 控制台，所以键盘被关掉后
`Ctrl+Alt+F2` + `internal-keyboard on` 永远能救回来。

本仓库按官方 `/noctalia-dev/official-plugins`、`/noctalia-dev/community-plugins` 的目录规范
组织，可直接作为 `path` / `git` 源使用；同一份代码已提交到社区插件商店（见下方 PR）。

```
catalog.toml          # 源索引：每个插件一行 [[plugin]]
.luaurc               # Luau languageMode = nonstrict
install.sh            # 注册本仓库为 path 源并启用插件
uninstall.sh          # 卸载（--purge 同时删除后端）
tests/smoke.sh        # 清单/入口/翻译/后端自检（CI 也跑这个）
.github/workflows/    # checks
internal-keyboard/    # 目录名 = 插件 id 中 "/" 之后的部分
```

## 安装

```sh
git clone https://github.com/Goldppx/noctalia-internal-keyboard.git
cd noctalia-internal-keyboard
./install.sh --setup    # 注册源 + 启用插件 + 跑一次 root 后端安装
sh tests/smoke.sh       # 自检
```

后端需要一次 root（root 所有的 CLI、一条 udev 规则、一条只允许四个子命令的 sudoers 条目）：

```sh
sudo internal-keyboard/setup.sh     # 等价于 ./install.sh --setup
```

脚本会先列出机器上的键盘，选中内置的那块（`i8042/serio0`），并把状态复位为「开」。

依赖：

| 依赖 | 用途 |
|---|---|
| `sudo` | 磁贴/挂件免密调用后端 |
| `udevadm` | 重新宣告设备，让 libinput 重读忽略属性 |
| `sh` | 后端与安装脚本是 POSIX shell |
| libinput 系合成器 | niri / Hyprland / Sway 等；Xorg 会话不支持 |

## 使用

- **控制中心磁贴**：设置 → 控制中心 → 快捷方式 → 添加「Internal Keyboard」；高亮 = 已关闭
- **栏挂件**：可选，点击切换，右键重新读取状态
- **OSD**：每次切换弹出键盘图标的提示，可在设置里关闭（默认开）
- **换哪块键盘**：设置 → 插件 → Internal Keyboard → `Keyboard` 填设备全名
  （`internal-keyboard devices` 列出候选，留空 = setup.sh 选的那块）
- **TTY / 终端**：

  ```sh
  internal-keyboard status     # state=on|off, device=..., available=0|1, nodes=...
  internal-keyboard devices    # * 标出当前键盘
  internal-keyboard off | on | toggle
  ```

- **键位**：插件不会替你写键位。想绑的话自己加：

  ```kdl
  Mod+Shift+K { spawn-sh "noctalia msg plugin goldesquemoon/internal-keyboard:service all toggle"; }
  ```

## 原理

```
磁贴/挂件/键位 ──► service.luau ──sudo -n──► internal-keyboard off
                                                │
                     /run/internal-keyboard/disabled ◄─┘
                                                │
                          udevadm trigger --action=remove  (libinput 忘掉设备)
                          udevadm trigger --action=add     (规则重跑)
                                                │
    /etc/udev/rules.d/90-internal-keyboard.rules → LIBINPUT_IGNORE_DEVICE=1
                                                │
                  libinput evdev_device_create() 丢掉设备 → 合成器收不到按键
```

必须 remove+add，不能只发 `change`：libinput 只在设备 **add** 时读 `LIBINPUT_IGNORE_DEVICE`
（`evdev_udev_handler` 只处理 add/remove，二进制里没有 `change` 字面量）。标志文件放在 `/run`
（tmpfs），所以开机永远默认启用。

## 提交状态

| 项目 | 链接 |
|---|---|
| 社区插件 PR | <https://github.com/noctalia-dev/community-plugins/pull/1267>（Draft） |
| 插件目录 | `internal-keyboard/`（`plugin.toml`、`README.md`、`thumbnail.webp`、`translations/en.json` 齐全） |

## 许可

MIT
