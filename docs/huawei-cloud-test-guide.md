# 秒算虾料 · 华为云调试 / 云测试 + 发布签名 全流程

> 适用工程：`D:\mixcalc-harmony`（`com.shrimpfarm.mixcalc`，0.3.4 / versionCode 1000304）
> 目标：不买平板，用华为云真机验证平板横屏/竖屏适配；再跑一次云测试兼容性报告。
> 说明：AGC 控制台菜单会随版本微调，找不到时按「质量 / 测试服务 → 云调试 / 云测试」这条线找；以你登录后看到的为准。

---

## 0. 先分清三个东西，别走错入口

| 名称 | 到底是什么 | 交互方式 | 最适合 |
|---|---|---|---|
| **云调试** | 浏览器远程操作一台**云真机 / 仿真机**，一次一般 60 分钟 | **手动**：点击、滑动、打字、截图、看日志 | 平板 UI、键盘、表尾遮挡、截图取证 |
| **云测试** | 在设备池里**自动跑**兼容性 / 稳定性 / 性能，出报告 | **自动**：上传包、选机型、等报告 | 安装/启动/崩溃/多机型回归 |
| **本地签名打包** | 生成 **release 签名 HAP** | 命令行或 DevEco | 上面两个的入场券 |

**结论：平板适配先走「云调试」，因为你要亲眼确认 11 列、行高、键盘、表尾这些视觉和交互；「云测试」用来补自动化报告和崩溃/启动覆盖。**

另外纠正一个常见说法：华为云上不是把包丢进"模拟器"里跑。云调试里有**仿真机**，但更推荐选**真机 MatePad**；云测试跑的是**真机设备池**。真机的输入法、性能、屏幕像素才和用户一致。

> 注意：这里说的是**华为开发者联盟 AppGallery Connect（AGC）**里的「云调试 / 云测试」，不是华为云（Huawei Cloud）控制台里的服务。入口是 AGC，不是华为云。 

---

## 1. 你工程现在的状态（我已核对）

| 项目 | 现状 | 对云测的影响 |
|---|---|---|
| 包名 | `com.shrimpfarm.mixcalc` | AGC 里必须建同名应用，建错不能改 |
| 版本 | `0.3.4` / `1000304` | 每轮上传建议 +1，避免缓存/重复 |
| 设备类型 | `phone` + `tablet` | 平板能装，OK |
| 屏幕方向 | `orientation: auto_rotation`；手机运行时锁 `PORTRAIT`，平板 `AUTO_ROTATION` | 平板横屏/竖屏都要验；手机仍应锁竖屏 |
| 窗口模式 | `supportWindowMode: ["fullscreen"]` | 平板应直接全屏启动，不再以自由窗口打开 |
| SDK | `compatibleSdkVersion` / `targetSdkVersion` = `6.0.1(21)` | 云机系统必须 ≥ 6.0.1，否则装不上 |
| 现有签名 | `build-profile.json5` 里只有 `default`，别名 `debugKey`，文件在 `C:\Users\Administrator\.ohos\config\default_mixcalc...` | **这是自动调试签名，不是发布签名** |
| 现有 HAP | `entry/build/default/outputs/default/entry-default-signed.hap` | 由 `BUILD_MODE_NAME=debug` 构建，**云调试/云测试会拒** |
| 平板代码 | `MixCalcTable.isTabletMode()`：`viewW >= 600` 走平板列宽；`ensureWidths()` 均分 → ×1.2/×0.8 → 夹 50~120 → 整体铺满 | 代码分支已就位，缺的是云上真机验证 |

**一句话：代码侧准备度 OK，现在卡在「发布证书 + release 签名包」。** 现有那个 `signed.hap` 不要传，传了大概率报「应用非 Release 版本」。

---

## 2. 全流程一页纸（建议按这个顺序）

```
0. 华为开发者账号 + 实名认证
1. AGC 建项目 → 添加 HarmonyOS 应用（包名必须一致）
2. 生成 .p12 + .csr（keytool 或 DevEco）
3. AGC「证书」→ 新增发布证书 → 下载 .cer
4. AGC「Profile」→ 新增发布 Profile → 下载 .p7b
5. 配 release 签名（DevEco GUI）或直接手签（CLI）
6. 打 release HAP（buildMode=release）
7. AGC「质量 → 云调试」→ 选 MatePad → 上传 HAP → 手动验收
8. 按第 11 节清单逐项截图
9. AGC「质量 → 云测试」→ 自定义/兼容性测试 → 选平板 → 出报告
10. 修问题 → versionCode +1 → 重打重传
11. 定版：versionCode/versionName、图标、隐私外链、软著、上架
```

首次走完，**顺利的话 2~4 小时**（不含实名审核、设备排队、测试报告等待）。

---

## 3. 第 0 步：账号与 AGC 应用（只有你能做）

### 3.1 账号

1. 打开 [华为开发者联盟](https://developer.huawei.com/consumer/cn/) 注册/登录。
2. 完成**实名认证**（个人或企业）。云调试、云测试、证书申请都依赖实名账号。
3. 如果实名还在审核，先去把第 4 节的 CSR 生成好，不耽误。

### 3.2 AGC 建项目 / 应用

1. 打开 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)。
2. 「我的项目」→「添加项目」，项目名例如 `MixCalc`。
3. 进入项目 →「添加应用」：
   - 平台选 **HarmonyOS**
   - 应用包名：`com.shrimpfarm.mixcalc`（**一个字都不能差**）
   - 应用名称：`秒算虾料`
   - 分类：工具类即可
4. 建完后确认应用列表里能看到这个包名。

> 包名建错不能改，只能新建应用重来；所以先核对 `AppScope/app.json5`。

---

## 4. 第 1 步：生成密钥和 CSR（DevEco 或 keytool）

> 产出：`.p12`（私钥库）+ `.csr`（证书请求）。这两个是"根"，丢了以后无法更新应用。
>
> **没有 DevEco Studio？** 跳过本节，直接看 **8.5 纯 CLI 路线**：用 JDK 自带的 `keytool` 生成，效果一样。

1. 打开 DevEco Studio，菜单 **Build → Generate Key and CSR**。
2. 没有现成密钥库就选 **New**：
   - Key store path：`D:\mixcalc-sign\mixcalc-release.p12`（**不要放工程目录**）
   - Password：强密码（至少 8 位，大小写/数字/特殊字符至少两类）
   - Key alias：`mixcalc`
   - Key password：可与 store 相同，也可不同，**记牢**
   - Validity：建议 **25 年**（覆盖应用生命周期）
   - 组织/CN 等可填真实信息，也可留空
3. 下一步，CSR 路径：`D:\mixcalc-sign\mixcalc-release.csr`。
4. 完成后确认两个文件都存在。

**立刻做备份**：`D:\mixcalc-sign` 整个目录 + 密码/别名，存密码管理器或加密网盘。后面换电脑、重装系统都要用。

---

## 5. 第 2 步：AGC 申请发布证书 `.cer`

1. AGC →「证书、App ID 和 Profile」→「证书」页签。
2. 点「新增证书」：
   - 证书名称：`mixcalc-release`
   - 证书类型：**发布证书**（不要选调试证书）
   - 上传：`mixcalc-release.csr`
3. 提交后，在列表里点「下载」，得到 `mixcalc-release.cer`，放到 `D:\mixcalc-sign\`。

> 发布证书和调试证书的区别：调试证书签的包只能在 Profile 里登记过 UDID 的设备上装；云机不在你的设备列表里，所以云调试只认发布证书 + 发布 Profile。

---

## 6. 第 3 步：AGC 创建发布 Profile `.p7b`

1. 同一页面切到「Profile」→「添加」。
2. 填写：
   - 所属应用：`秒算虾料`（`com.shrimpfarm.mixcalc`）
   - Profile 名称：`mixcalc-release-profile`
   - 类型：**发布**（不要选调试）
   - 证书：选刚创建的 `mixcalc-release`
   - 权限：本应用目前没有申请受限权限，保持默认即可；如果以后加了相机/定位等，要在这里勾上
   - 设备：**发布 Profile 不需要添加设备**（调试 Profile 才需要 UDID）
3. 保存后下载 `mixcalc-release-profile.p7b`，放到 `D:\mixcalc-sign\`。

> 如果页面出现「设备」选择，先确认你点的是不是 **「指定设备发布 Profile」**（那是给内部测试分发包用的，需要逐个填 UDID）。云调试/云测试要用**普通「发布 Profile」**，不需要设备；选错会导致云机提示「设备不依赖」。

最终你手里应该有 4 个文件：

| 文件 | 作用 | 是否进 Git |
|---|---|---|
| `mixcalc-release.p12` | 私钥库，签名核心 | **绝对不能** |
| `mixcalc-release.csr` | 证书请求，留档 | 不建议 |
| `mixcalc-release.cer` | 发布证书 | 不建议 |
| `mixcalc-release-profile.p7b` | Profile（绑应用/证书/类型） | 不建议 |

> 这 4 个文件 + 两个密码，就是"签名三件套 + 私钥"。**建议再备份一份到离线介质**。

---

## 7. 第 4 步：工程配置 release 签名

### 7.1 推荐：DevEco 图形界面

> 没有 DevEco Studio 可以跳过 7.1 / 7.2，直接走 8.5 的纯 CLI 路线（打 unsigned 包 + `hap-sign-tool` 手签）。

1. **File → Project Structure → Project → Signing Configs**。
2. 取消勾选 **Automatically generate signature**（自动签名只能出 debug，不能用于云测）。
3. 点 `+` 新增一个配置：
   - Name：`release`
   - Type：`HarmonyOS`
   - Store File：`D:\mixcalc-sign\mixcalc-release.p12`
   - Store Password：p12 密码
   - Key Alias：`mixcalc`
   - Key Password：key 密码
   - Certpath：`D:\mixcalc-sign\mixcalc-release.cer`
   - Profile：`D:\mixcalc-sign\mixcalc-release-profile.p7b`
   - Sign Alg：`SHA256withECDSA`
4. Apply。

> 让 DevEco 自己写 `build-profile.json5`，它会按 IDE 的方式处理密码字段；手改容易遇到密码格式/转义问题。

### 7.2 然后切换 product 的签名配置

打开根目录 `build-profile.json5`，把 `products[0].signingConfig` 从 `'default'` 改成 `'release'`：

```json5
{
  app: {
    signingConfigs: [
      {
        name: 'default',
        type: 'HarmonyOS',
        material: { /* 原来的自动调试签名，保留，本地调试还要用 */ }
      },
      {
        name: 'release',
        type: 'HarmonyOS',
        material: {
          certpath: 'D:/mixcalc-sign/mixcalc-release.cer',
          keyAlias: 'mixcalc',
          keyPassword: '<让 DevEco 写入，不要手填明文>',
          profile: 'D:/mixcalc-sign/mixcalc-release-profile.p7b',
          signAlg: 'SHA256withECDSA',
          storeFile: 'D:/mixcalc-sign/mixcalc-release.p12',
          storePassword: '<让 DevEco 写入，不要手填明文>'
        }
      }
    ],
    products: [
      {
        name: 'default',
        compatibleSdkVersion: '6.0.1(21)',
        targetSdkVersion: '6.0.1(21)',
        runtimeOS: 'HarmonyOS',
        signingConfig: 'release'   // ← 云测期间改成 release
      }
    ]
  }
}
```

**两种包的切换关系：**

| 用途 | signingConfig | buildMode | 能否本机 hdc 安装 |
|---|---|---|---|
| 本地真机调试 | `default` | `debug` | 能（设备 UDID 已在调试 Profile 里） |
| 云调试 / 云测试 | `release` | `release` | 不能，**这是正常的**，云服务侧安装 |

> 发布签名包在本机装不上不是打包失败，是系统策略；不要因此反复重打。

### 7.3 不想来回改？用双 product（可选，见附录 A）

给 `release` 单独建一个 product，以后 `-p product=release` 直接出云测包，`default` 保持本地调试。第一次建议先按 7.2 走通，再考虑这个。

---

## 8. 第 5 步：打 release HAP

### 8.1 命令行（和你现在 PLAN 里的方式一致）

```powershell
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"
$env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony

hvigorw.bat clean --no-daemon
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=release --no-daemon
```

> 如果 `clean` 不认 `--no-daemon`，去掉即可。构建前确认 7.2 已把 `signingConfig` 改成 `release`。

产物：

```
entry\build\default\outputs\default\entry-default-signed.hap
```

检查一下时间戳和大小：

```powershell
Get-Item entry\build\default\outputs\default\entry-default-signed.hap |
  Select-Object FullName, Length, LastWriteTime
```

### 8.2 DevEco 图形界面

1. 左侧 **Build Variants** 面板，把 `entry` 的 Build Variant 设为 `release`。
2. 菜单 **Build → Build Hap(s)/APP(s) → Build Hap(s)**。
3. 产物同上。

### 8.3 可选：验一下签名

在 SDK 里找 `hap-sign-tool.jar`（一般在 `sdk\default\openharmony\toolchains\lib\`）。`java` 用系统 JDK，或 DevEco 自带的 `jbr\bin\java.exe`：

```powershell
New-Item -ItemType Directory -Force dist | Out-Null
java -jar "$root\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar" verify-app `
  -inFile "entry\build\default\outputs\default\entry-default-signed.hap" `
  -outCertchain "dist\verify-certchain.cer" `
  -outProfile "dist\verify-profile.p7b"
```

能正常输出证书链/Profile 就说明包是签过的；具体签名主体也可以在 AGC 证书页面对照。

### 8.4 Plan B：先打 unsigned，再用 hap-sign-tool 手签

如果 hvigor 的签名任务报错，或者你想在 CI 里签，可以：

1. 临时把 `products[0].signingConfig` 去掉，`buildMode=release` 打出 `entry-default-unsigned.hap`。
2. 用 `hap-sign-tool` 签：

```powershell
$storePwd = Read-Host "p12 密码"
$keyPwd   = Read-Host "key 密码"

java -jar "$root\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar" sign-app `
  -mode "localSign" `
  -keyAlias "mixcalc" `
  -signAlg "SHA256withECDSA" `
  -appCertFile "D:\mixcalc-sign\mixcalc-release.cer" `
  -profileFile "D:\mixcalc-sign\mixcalc-release-profile.p7b" `
  -inFile "entry\build\default\outputs\default\entry-default-unsigned.hap" `
  -keystoreFile "D:\mixcalc-sign\mixcalc-release.p12" `
  -outFile "dist\mixcalc-0.3.4-release-signed.hap" `
  -keyPwd "$keyPwd" `
  -keystorePwd "$storePwd"
```

> 手签适合排错/CI；第一次建议先用 8.1 让 hvigor 自动签，少一个变量。

### 8.5 没有 DevEco Studio：纯 CLI 路线（keytool + hap-sign-tool）

结论先说：

- **能生成 `.p12` / `.csr`**：JDK 自带的 `keytool` 就能做；
- **不能"纯 CLI 拿华为证书"**：`.cer` / `.p7b` 必须登录 AGC 网页，上传 CSR 后下载；官方没有公开的"命令行签发发布证书"接口；
- **能纯 CLI 打包 + 签名**：`hvigorw` 出 unsigned HAP，`hap-sign-tool` 签成 release HAP。

你机器上的现成路径：

| 工具 | 路径 |
|---|---|
| JDK 21 keytool | `C:\Program Files\Java\jdk-21\bin\keytool.exe` |
| JDK 21 java | `C:\Program Files\Java\jdk-21\bin\java.exe` |
| hap-sign-tool | `D:\command-line-tools\command-line-tools\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar` |

#### ① 生成 p12 + csr（keytool）

> 不想复制命令：直接跑仓库里的 [`scripts/init-signing.ps1`](../scripts/init-signing.ps1)，按提示输入密码即可；脚本只生成 p12/csr，不保存密码。
> 脚本是**纯 ASCII**（注释/提示全英文），Windows PowerShell 5.1 直接跑，不需要改 UTF-8 BOM。

```powershell
$jdk  = 'C:\Program Files\Java\jdk-21\bin'
$sign = 'D:\mixcalc-sign'
New-Item -ItemType Directory -Force $sign | Out-Null

$p12Pwd = Read-Host "设置 p12 密码（至少 8 位，字母/数字/符号至少两类）"

& "$jdk\keytool.exe" -genkeypair `
  -alias "mixcalc" `
  -keyalg EC `
  -groupname secp256r1 `
  -sigalg SHA256withECDSA `
  -dname "C=CN,O=shrimpfarm,OU=mixcalc,CN=mixcalc" `
  -keystore "$sign\mixcalc-release.p12" `
  -storetype pkcs12 `
  -validity 9125 `
  -storepass $p12Pwd `
  -keypass $p12Pwd

& "$jdk\keytool.exe" -certreq `
  -alias "mixcalc" `
  -keystore "$sign\mixcalc-release.p12" `
  -storetype pkcs12 `
  -sigalg SHA256withECDSA `
  -file "$sign\mixcalc-release.csr" `
  -storepass $p12Pwd
```

说明：

- `-validity 9125` = 25 年；`-keyalg EC` + `secp256r1` 对应 NIST-P-256，和 `SHA256withECDSA` 匹配。
- 如果 keytool 不认 `-groupname`，去掉它；JDK 21 默认 EC 曲线就是 secp256r1。
- p12 和 key 用同一个密码（PKCS12 不支持分开）。
- 生成的 `.p12` 里是**自签证书**，只用于发起 CSR，不是华为认可的发布证书；华为证书要等 AGC 签发。

#### ② 去 AGC 网页换 `.cer` / `.p7b`

同第 5、6 节，只有两步需要浏览器：

1. 证书 → 新增证书 → **发布证书** → 上传 `mixcalc-release.csr` → 下载 `mixcalc-release.cer`。
2. Profile → 添加 → **发布** → 选应用 `com.shrimpfarm.mixcalc` + 证书 → 下载 `mixcalc-release-profile.p7b`。

> 这一步替代不了：AGC 要校验你的账号、应用和 CSR，命令行没有公开接口。

#### ③ 打 unsigned release HAP

把 `build-profile.json5` 的 `products[0].signingConfig` 这一行删掉（或注释），让 hvigor 不签名：

```powershell
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"
$env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony

hvigorw.bat clean --no-daemon
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=release --no-daemon
```

产物：

```
entry\build\default\outputs\default\entry-default-unsigned.hap
```

#### ④ 用 hap-sign-tool 签成 release HAP

```powershell
$jar = "$root\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar"
New-Item -ItemType Directory -Force dist | Out-Null

& "$jdk\java.exe" -jar $jar sign-app `
  -mode "localSign" `
  -keyAlias "mixcalc" `
  -keyPwd $p12Pwd `
  -signAlg "SHA256withECDSA" `
  -appCertFile "$sign\mixcalc-release.cer" `
  -profileFile "$sign\mixcalc-release-profile.p7b" `
  -inFile "entry\build\default\outputs\default\entry-default-unsigned.hap" `
  -keystoreFile "$sign\mixcalc-release.p12" `
  -keystorePwd $p12Pwd `
  -outFile "dist\mixcalc-0.3.4-release-signed.hap"
```

> `$p12Pwd` 要和你 ① 设置的一致；新开 PowerShell 窗口就重新赋值。JDK 21 如果跑 `hap-sign-tool` 报算法/类版本错误，把 `$jdk` 换成 `C:\Program Files\Java\jdk-17\bin`。

#### ⑤ 验签

```powershell
& "$jdk\java.exe" -jar $jar verify-app `
  -inFile "dist\mixcalc-0.3.4-release-signed.hap" `
  -outCertchain "dist\verify-certchain.cer" `
  -outProfile "dist\verify-profile.p7b"
```

注意参数是 `-outCertchain`（小写 c），不是 `-outCertChain`；如果工具版本不认，跑 `java -jar $jar -help` 看实际参数。

#### ⑥ 上传

同第 9 / 10 节，传 `dist\mixcalc-0.3.4-release-signed.hap`。

---

## 9. 第 6 步：云调试（平板手动验收）

### 9.1 入口

两条路都行：

- **AGC 控制台**：我的项目 → 选 `MixCalc` → 左侧「质量」→「云调试」
  （老界面可能叫「测试服务 → 云调试」）
- **开发者联盟**：[云调试页面](https://developer.huawei.com/consumer/cn/agconnect/cloud-adjust/) → 登录 → 进入云调试

### 9.2 选设备

1. 设备列表按 **平板 / Tablet** 筛选，优先 **MatePad**。
2. 看三个信息：
   - 系统版本：必须 **≥ 6.0.1**（你的 `compatibleSdkVersion` 是 6.0.1(21)）
   - API Level：≥ 21
   - 状态：空闲 / 占用
3. 点「申请设备」，等浏览器出现投屏画面。
4. 一次一般 **60 分钟**，超时自动断开；忙时用「预约」。

> 如果列表里只有 5.x 的平板，先别硬装：要么换 6.x 设备/仿真机，要么把 `compatibleSdkVersion` 临时降到 5.0.x 再验证（改完要重新回归，不建议一上来就降）。

### 9.3 上传安装

1. 点「上传应用」/「安装应用」，选 `entry-default-signed.hap`（release 包）。
2. 上传后会自动安装。
3. 首次进入先过隐私弹窗：同意 → 主界面。

> 如果 MatePad 仍以**自由窗口**打开（标题栏有最小化/最大化/关闭），先确认 `module.json5` 的 `supportWindowMode` 是 `["fullscreen"]` 并已打进 HAP；正常应直接全屏。窗口模式下 `viewW` 是窗口内容宽度，不是屏幕物理宽度，列会按窗口铺满，看起来“没识别屏幕宽度”。

**如果报错：**

| 提示 | 原因 | 处理 |
|---|---|---|
| 应用非 Release 版本 | 用了 debug 构建 / 自动签名 | 回第 7、8 节，`signingConfig=release` + `buildMode=release` 重打 |
| 签名校验失败 / 安装失败 | p12 / cer / p7b 不匹配，别名或密码错，Profile 绑错应用 | 核对 4 个文件、别名、密码；Profile 必须选对 `com.shrimpfarm.mixcalc` |
| 设备不依赖 / device not in profile | 用了调试 Profile | 换成发布 Profile（发布 Profile 不需要设备 UDID） |
| API version not supported | 云机系统低于 6.0.1 | 换设备，或临时降低 `compatibleSdkVersion` |
| HAP 解析失败 | 传了 zip / 改过后缀 | 传原始 `.hap`，不要解压/改名 |

### 9.4 远程操作 + 取证

- 鼠标点击 = 手指点击；拖拽 = 滑动。
- 点输入框后可直接用电脑键盘打字（比在手机上敲长文本方便）。
- 控制面板有返回 / 主页 / 多任务 / 音量 / 电源。
- **截图按钮**：每验完一项截一张，命名 `tablet-01-layout.png`、`tablet-02-keyboard.png`……
- 日志面板：实时看 hilog，可过滤 `com.shrimpfarm.mixcalc`。
- Shell 输入框可以下发 hdc 命令：

```text
hdc shell param get const.product.model
hdc shell param get const.ohos.apiversion
hdc shell aa dump -l
hdc shell aa dump -a com.shrimpfarm.mixcalc
hdc hilog -Q asc f
```

> 60 分钟到点会断开，**关键截图和日志提前导出**，不要卡最后一分钟。

### 9.5 一帧多屏（强烈推荐）

云调试支持同时申请 2~4 台设备，主控设备操作同步到所有设备。

- 选「一帧多屏」→ 混选一台手机 + 一台 MatePad → 上传一次，全部安装。
- 主控上点格子、弹键盘、切批次，旁边平板同步看效果。
- 适合对比：手机固定列宽 vs 平板铺满、键盘弹起时表尾位置、字体/行高观感。
- 尽量选同品牌（都华为），跨品牌延迟可能不一致。

---

## 10. 第 7 步：云测试（自动化报告）

### 10.1 入口

AGC → 我的项目 → `MixCalc` → 左侧「质量」→「云测试」（老界面「测试服务 → 云测试」）。

### 10.2 建任务

1. 点「创建测试」。
2. 选类型：
   - **兼容性测试**：安装/启动/运行/崩溃，最适合第一次
   - **稳定性测试**：Monkey 长时间跑，看崩溃/ANR/内存
   - **性能测试**：启动耗时、CPU、内存、帧率
   - **UX 测试**：需要脚本/标注，先不急
3. 上传**同一个 release HAP**（如果页面只收 APP，就用 `hvigorw.bat assembleApp --mode module -p product=default -p buildMode=release --no-daemon` 打 `.app` 再传）。
4. 设备选 **平板 / MatePad**。如果当前账号的设备列表里没有平板，说明这个服务当前设备池/套餐不含平板——**那就回云调试的 MatePad 做手动验证**，云测试选手机跑一遍启动/崩溃回归也有价值。
5. 创建任务，等报告（几分钟到几十分钟，看排队）。

### 10.3 报告怎么看

| 模块 | 看什么 |
|---|---|
| 总览 | 通过率、失败设备数、安装/启动成功率 |
| 单机详情 | 哪台失败、失败步骤、截图 |
| 崩溃/ANR | 堆栈、日志、复现步骤 |
| 性能 | 启动耗时、内存峰值、CPU、帧率（如果有） |
| 截图 | 首屏/关键步骤，能看出布局是否错位 |
| 日志 | 可下载，和本地 hilog 对照 |

> 云测试的 Monkey 是随机点，**不一定能覆盖你的表格录入流程**；它擅长发现启动崩溃、兼容性安装失败、内存/稳定性问题。功能细节还是要靠云调试手动点。

### 10.4 上架测试 vs 自定义测试

- **自定义测试**：自己上传包、选机型，适合发版前。
- **上架测试**：跟着应用市场提交流程走，适合准备上架时。
- 现在用**自定义测试**即可。

---

## 11. 平板验收清单（云调试时照着点）

> 建议每项截图，最后拼成一份 `tablet-validation.md` 或直接发我截图。

### A. 启动 / 隐私
- [ ] 首次启动隐私弹窗宽度约 85%，标题 18、正文 13
- [ ] 正文里「隐私政策」「用户协议」可点，能打开网页
- [ ] 点「拒绝」能退出；点「同意」进主界面
- [ ] 状态栏绿色 `#1F6B30`、导航栏白色

### B. 表格布局（重点）
- [ ] 11 列**一次全显示**，不需要横向滑动
- [ ] 右侧没有留白/缺列，最后一列贴边
- [ ] 序号/平均列略窄，棚号/称料列略宽（×0.8 / ×1.2 的观感）
- [ ] 列宽都在 50~120vp 内，没有挤成一条线
- [ ] 行高 40、字号 14，和手机版观感一致
- [ ] 表头吸顶、表尾吸底；表尾料/水为空时显示 `0`
- [ ] 冻结列不透明，横向滚动时不透底

### C. 单元格编辑 / 键盘
- [ ] 点格子 → 编辑框正好盖住格子，光标在数据末尾
- [ ] 键盘弹出 → 表尾露在键盘上方（RESIZE 生效），表格没有被顶飞
- [ ] 平板横屏时键盘也是全宽平铺，表尾仍然在键盘上方（不是覆盖）
- [ ] 按键盘「下一步」→ 同向右移，**键盘不闪、不收起**
- [ ] 行末按下一步 → 换到下一行行首
- [ ] 右下角「下一行 ▾」→ 同列向下
- [ ] 数字列只出数字键盘，只能输数字/小数点；棚号列白名单生效
- [ ] 编辑中直接点另一格 → 不闪、不双键盘
- [ ] 前面有空行时拦截并弹提示；中间清空后已有数据的行仍可改

### D. 菜单 / 弹窗
- [ ] 长按表头 → 列菜单；固定/隐藏/显示全部/取消固定
- [ ] 隐藏列后可见列重新铺满，不出现右侧空白
- [ ] 快捷设置：9 列、灰/绿切换、全取消/全解固/列全显/全确认
- [ ] 水比 / 发酵料表头弹窗；当前值打 ✓、浅绿高亮
- [ ] 长按料格 → 换料比例 10%~90%；改过数值后失效
- [ ] 所有弹窗压在编辑框之上，不被输入框穿透

### E. 数据 / 批次
- [ ] 批次 01/02 切换，标题批次号正确，子菜单带 ✓
- [ ] 两批数据互不干扰
- [ ] 杀进程重开 → 数据还在
- [ ] 重置弹窗：有数据/无数据两套文案，按钮颜色正确，重置后清空

### F. 语言 / 网页 / 转屏
- [ ] 中文/English 切换，表格和网页都跟着变
- [ ] 帮助、隐私、协议网页能打开、能返回
- [ ] 平板横屏/竖屏都能铺满，11 列按当前窗口宽度均分
- [ ] 手机仍然锁竖屏，不跟随旋转

### G. 性能 / 稳定性
- [ ] 快速滑动表格不卡顿、不白屏
- [ ] 连续编辑 10 行、切批次、弹键盘多次，无崩溃/ANR
- [ ] 放置 3~5 分钟，内存没有明显持续上涨

---

## 12. 结果怎么判、怎么回归

1. **先判"能不能装、能不能开"**：云测试报告里安装/启动失败 = P0，先修。
2. **再判布局**：11 列是否全显、右侧是否留白、键盘是否挡表尾 = P1。
3. **最后判交互细节**：键盘闪、光标位置、弹窗层级 = P2。
4. 每修一轮：
   - `AppScope/app.json5` 的 `versionCode` +1（例如 `1000305`），`versionName` 同步（例如 `0.3.5`）
   - 重打 release HAP
   - 云调试复验对应项
   - 云测试可只跑兼容性回归
5. 所有截图/日志按 `tablet-<轮次>-<项>.png` 存档，发版时能当测试证据。

> 云测试/云调试可能按 versionCode 缓存，**每轮务必 +1**，否则可能还在跑旧包。

---

## 13. 常见问题速查

| 现象 | 最可能原因 | 处理 |
|---|---|---|
| 上传提示「应用非 Release 版本」 | `buildMode=debug` 或用了 `default` 调试签名 | 改 `signingConfig=release`，`buildMode=release` 重打 |
| 安装失败「签名校验失败」 | p12 / cer / p7b 不是一套；别名/密码错 | 重新走第 4~6 节，四件套对齐；用 `verify-app` 验 |
| 「Profile 绑定的应用不匹配」 | AGC Profile 选错应用，或包名不一致 | Profile 选 `com.shrimpfarm.mixcalc`；核对 `app.json5` |
| 「设备不依赖 / not in profile」 | 用了调试 Profile | 换发布 Profile；发布 Profile 不加设备 |
| 「API version not supported」 | 云机 < 6.0.1 | 换设备/仿真机；或临时降 `compatibleSdkVersion`（需回归） |
| 上传 HAP 解析失败 | 传了 zip、改后缀、包损坏 | 传原始 `.hap`；重新构建 |
| 装上了但白屏/闪退 | 代码/资源问题，不是签名 | 云调试日志面板看 hilog；`aa dump -l` 看页面栈 |
| 云机一直被占 | 热门机型 | 用预约；换型号；避开高峰 |
| 60 分钟断开 | 会话到时 | 重新申请；提前导出截图/日志 |
| release 包本机装不上 | 系统策略 | 正常，去云上装；本机调试换回 `default` |

---

## 14. 费用 / 时长 / 配额（以控制台为准）

- **证书 / Profile**：免费。
- **云调试**：部分机型每天有 **300 分钟免费**额度，其他机型/超出部分按套餐计费；单次一般 60 分钟。
- **云测试**：通常有免费额度/体验次数，超出买套餐；具体看「云测试 → 套餐/额度」页面。
- **实名审核**：个人一般较快，企业可能 1~2 个工作日；别等到要提审才做。

> 第一次建议先用免费额度把 MatePad 云调试跑通，再决定要不要买云测试套餐。

---

## 15. 我能帮你什么 / 你必须自己做什么

**你必须自己做（涉及账号和安全）：**
- 注册/实名华为开发者账号
- 登录 AGC 建项目/应用
- 在 AGC 下载 `.cer` / `.p7b`
- 上传 HAP、操作云真机、下载报告

**我可以接着帮你：**
- 你把 AGC 页面/报错截图发我，我按页面告诉你点哪里
- 你拿到 `.cer` / `.p7b` 后，我帮你核对 `build-profile.json5` 的 release 配置
- 云调试截图发我，我逐项对照第 11 节找布局/交互差异
- 云测试报告/日志发我，我帮你定位崩溃/ANR
- 需要的话，我再帮你把 release 打包 + 上传前检查做成脚本

**我不能做的：** 登录你的华为账号、替你点 AGC、替你上传包（这些都需要你的账号权限）。

---

## 16. 上架用 `.app`：CLI 一键打包

云调试用的 `.hap` **不能当发布包**。AppGallery 正式发布要 `.app`：

| 包型 | 用途 | 上架 |
|---|---|---|
| `.hap` | 单模块安装包，云调试/真机安装 | 不能直接上架 |
| `.app` | 应用包，含 HAP + `pack.info` | AppGallery 用这个 |

项目里已经放了脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\mixcalc-harmony\scripts\build-release-app.ps1
```

它会：

1. 检查 `D:\mixcalc-sign` 里的 `mixcalc-release.p12` / `.cer` / `.p7b`；
2. 提示输入 p12 密码；
3. 临时注释掉 `build-profile.json5` 里的 `signingConfig`，让 hvigor 出 **unsigned** `.app`；
4. `hvigorw clean` + `assembleApp --no-codesign`；
5. 用 `hap-sign-tool sign-app` 对 `.app` 做发布签名；
6. 把 `.app` 复制到 `dist`，并恢复 `build-profile.json5`。

> 为什么不让 hvigor 直接签：hvigor 要求的是 DevEco 生成的**加密密码**（≥32 位 hex），命令行直接写明文会报 `00303116 The length of the storePassword or keyPassword ... is less than 32`。所以这里走“unsigned APP + hap-sign-tool 手签”。

产物：

```
dist\mixcalc-<version>-release-signed.app     ← 上架传这个
```

云调试用的 `.hap` 仍用之前的 `dist\mixcalc-0.3.4-release-signed.hap`，不要混。

> 脚本运行期间 `build-profile.json5` 只是把 `signingConfig` 注释掉，不写密码。如果中途 Ctrl+C/崩溃，用同目录的 `build-profile.json5.bak` 覆盖回去再删掉。
>
> 上架资料里的隐私政策/用户协议填**外链 URL**；应用内菜单现在打开本地 `privacy.html` / `user.html` 不影响打包。

手动等价命令：

```powershell
# 1) 先保证 product 没有 signingConfig，打 unsigned APP
hvigorw.bat assembleApp -p product=default -p buildMode=release --no-daemon --no-codesign

# 2) 用 hap-sign-tool 签 APP
java -jar hap-sign-tool.jar sign-app -mode localSign -keyAlias mixcalc -keyPwd <pwd> `
  -signAlg SHA256withECDSA -appCertFile D:\mixcalc-sign\mixcalc-release-chain.pem `
  -profileFile D:\mixcalc-sign\mixcalc-release-profileRelease.p7b `
  -inFile <unsigned.app> -keystoreFile D:\mixcalc-sign\mixcalc-release.p12 `
  -keystorePwd <pwd> -outFile dist\mixcalc-0.3.4-release-signed.app
```

---

## 附录 A：双 product 配置（可选，熟练后再用）

如果不想每次改 `signingConfig`，可以给云测单独建一个 product：

```json5
{
  app: {
    products: [
      {
        name: 'default',
        compatibleSdkVersion: '6.0.1(21)',
        targetSdkVersion: '6.0.1(21)',
        runtimeOS: 'HarmonyOS',
        signingConfig: 'default'
      },
      {
        name: 'release',
        compatibleSdkVersion: '6.0.1(21)',
        targetSdkVersion: '6.0.1(21)',
        runtimeOS: 'HarmonyOS',
        signingConfig: 'release'
      }
    ]
  },
  modules: [
    {
      name: 'entry',
      srcPath: './entry',
      targets: [
        {
          name: 'default',
          applyToProducts: ['default', 'release']
        }
      ]
    }
  ]
}
```

构建：

```powershell
hvigorw.bat assembleHap --mode module -p product=release -p buildMode=release --no-daemon
```

产物一般在 `entry\build\release\outputs\release\entry-release-signed.hap`（以实际输出为准）。

---

## 附录 B：命令速查

```powershell
# 环境
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"
$env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony

# release 打包
hvigorw.bat clean --no-daemon
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=release --no-daemon

# 产物
entry\build\default\outputs\default\entry-default-signed.hap

# 验签（可选）
java -jar "$root\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar" verify-app `
  -inFile "entry\build\default\outputs\default\entry-default-signed.hap" `
  -outCertchain "dist\verify-certchain.cer" `
  -outProfile "dist\verify-profile.p7b"
```

---

## 附录 C：参考资料

- [云调试 · 调试应用（官方）](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/agc-help-clouddebug-debugapp-0000002289629821)
- [云测试 · 业务介绍（官方）](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/agc-help-cloudtest-introduction-0000002255036400)
- [云测试 · 自定义测试（官方）](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/agc-help-cloudtest-customizetest-0000002255036404)
- [手动签名（官方）](https://developer.huawei.com/consumer/cn/doc/harmonyOS-guides/ide-signing-manual)
- [发布应用 / 打包（官方）](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-publish-app)
- [云调试应用安装失败 FAQ（官方）](https://developer.huawei.com/consumer/cn/doc/doccenter-tools-faq/faqs-app-debugging-80)
- [云测试 FAQ（官方）](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-cloudtest-faq-0000001129745183)
- [云调试定价（官方）](https://developer.huawei.com/consumer/cn/doc/AppGallery-connect-Guides/agc-clouddebug-pricing-0000001213560484)

> 官方文档是前端渲染页，直接抓取可能只看到"文档中心"；上面链接用于你在浏览器里登录后查看。菜单名以你账号里的实际控制台为准。
