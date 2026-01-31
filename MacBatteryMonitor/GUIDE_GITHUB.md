# 如何将 MacBatteryMonitor 上传到 GitHub

以下是将你的项目上传到 GitHub 的详细步骤：

## 1. 准备工作

确保你已经注册了 [GitHub](https://github.com/) 账号，并在电脑上安装了 Git。

## 2. 初始化 Git 仓库

打开终端，进入项目目录（如果你还未在项目目录中）：

```bash
cd "/Users/lyon/Documents/bluetooth Android/MacBatteryMonitor"
```

初始化 Git 仓库：

```bash
git init
```

## 3. 添加文件

我已经帮你修改了 `.gitignore` 文件，确保你的图标文件 `AppIcon.iconset` 会被包含在内，而构建产生的临时文件会被忽略。

添加所有文件到暂存区：

```bash
git add .
```

提交更改：

```bash
git commit -m "Initial commit: MacBatteryMonitor app source code"
```

## 4. 在 GitHub 上创建新仓库

1. 登录 GitHub。
2. 点击右上角的 **+** 号，选择 **New repository**。
3. 仓库名称输入 `MacBatteryMonitor`（或其他你喜欢的名字）。
4. 保持 Public（公开）或 Private（私有）根据你的喜好。
5. **不要**勾选 "Initialize this repository with a README/gitignore/license"（因为我们本地已经有了）。
6. 点击 **Create repository**。

## 5. 推送代码到 GitHub

在 GitHub 仓库创建成功后的页面上，你会看到一串命令。复制其中的 "…or push an existing repository from the command line" 下面的部分。通常是这样的：

```bash
# 将 GitHub 仓库添加为远程仓库 (请将 YOUR_USERNAME 替换为你的 GitHub 用户名)
git remote add origin https://github.com/YOUR_USERNAME/MacBatteryMonitor.git

# 推送代码到主分支
git branch -M main
git push -u origin main
```

执行完上述命令后，刷新 GitHub 页面，你就能看到你的代码了！

## 常见问题

- **如果提示需要密码**：自 2021 年起，GitHub 不再支持密码验证。你需要使用 **Personal Access Token (PAT)** 或配置 **SSH Key**。

### 方法 A：使用 GitHub Desktop（最简单）
1. 下载并安装 [GitHub Desktop](https://desktop.github.com/)。
2. 登录你的 GitHub 账号。
3. 点击 "Add an Existing Repository from your Hard Drive..."。
4. 选择你的 `MacBatteryMonitor` 文件夹。
5. 点击 "Publish repository" 按钮即可一键上传。

### 方法 B：使用 SSH（推荐给开发者）
如果你已经配置了 SSH keys，直接使用 SSH 地址添加远程仓库：
`git remote add origin git@github.com:YOUR_USERNAME/MacBatteryMonitor.git`
