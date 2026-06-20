# [新手指导](https://github.com/wukongdaily/AutoBuildImmortalWrt/wiki) 👈🏻
# ImmortalWrt-ImageBuilder

**⚠️ 重要声明**

> **本项目为个人独立维护的第三方项目(脚本)，与 ImmortalWrt 官方没有关联。** <br>
> **项目中使用了 ImmortalWrt 官方 ImageBuilder 工具打包生成固件。<br>
> 但用户自行定制产生的任何 bug，均不代表 ImmortalWrt 官方固件的 bug**<br>
> **为了不给 ImmortalWrt 上游维护者增加额外负担和麻烦，所有相关问题请勿在 ImmortalWrt 群内反馈**。  <br>
> **建议各位在本项目 [Discussions](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder/discussions) 中提问或讨论**


---

[![GitHub](https://img.shields.io/github/license/wukongdaily/AutoBuildImmortalWrt.svg?label=LICENSE&logo=github&logoColor=%20)](https://github.com/wukongdaily/AutoBuildImmortalWrt/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/wukongdaily/AutoBuildImmortalWrt.svg?style=flat&logo=appveyor&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/wukongdaily/AutoBuildImmortalWrt.svg?style=flat&logo=appveyor&label=Forks&logo=github)

## 🤔 这是什么？
基于 CI 的 ImageBuilder 工作流，用于自动化构建 ImmortalWrt 固件。
> 1、支持自定义固件大小 默认1GB 不建议设置过大 推荐1G-2G 更大需求可通过自定义插件里的扩容插件自行扩容<br>
> 2、支持可选预安装docker（可选）支持在UI上勾选是否集成商店 （24.10.6以下）<br>
> 3、支持按需增加[第三方软件](https://github.com/wukongdaily/store/blob/master/README.md)  如何集成 https://github.com/wukongdaily/AutoBuildImmortalWrt/discussions/209 <br>
> 4、点击这里查看👉🏻[全部支持的机型列表](https://github.com/wukongdaily/AutoBuildImmortalWrt/blob/master/SUPPORT.md) 👈🏻<br>
> 5、在UI上 新增luci版本的可选项，默认最新版25.12.x https://github.com/wukongdaily/AutoBuildImmortalWrt/discussions/426<br>
> 6、支持设置管理地址的ip 比如192.168.100.1 这里强调 这项功能仅针对多网口机型 单网口的逻辑还是自动获取ip模式（dhcp）无固定ip<br>
> 7、对于[插件追新的用户 建议前往run项目 下载run后 ](https://github.com/wukongdaily/RunFilesBuilder/discussions/41)用命令sh xx.run 覆盖安装 <br>
> 8、支持24.10.x 、25.12.x 等版本 （包括x86-64-ISO、x86-64、rockchip、全志sunxi、无线路由器）

## [基本用法步骤](https://github.com/wukongdaily/AutoBuildImmortalWrt/wiki) 👈🏻
1、fork本项目<br>
2、在fork后的项目中 点击【action】 找到需要的工作流后 run-workflow<br>

## 如何查询imm仓库内有哪些插件
https://mirrors.sjtug.sjtu.edu.cn/immortalwrt/releases/24.10.4/packages/x86_64/luci/

## 如何查询imm仓库外目前可以集成哪些插件
https://github.com/wukongdaily/store
> 具体方法 https://github.com/wukongdaily/AutoBuildImmortalWrt/discussions/209

## ❤️其它GitHub Action项目推荐🌟 （建议收藏）⬇️
- ### [一键生成run插件] 🆕
- https://github.com/wukongdaily/RunFilesBuilder<br>
- ### [一键生成docker离线镜像] 🆕
- https://github.com/wukongdaily/DockerTarBuilder<br>
- ### [OpenWrt/Armbian IMG安装器ISO] 🆕
- https://github.com/wukongdaily/img-installer

<details>
<summary><h2>🍭相关引用</h2></summary>
#### 🍭引用和项目参考的仓库
- https://github.com/wukongdaily/RunFilesBuilder
- https://github.com/wukongdaily/store
- https://github.com/sirpdboy/luci-theme-kucat
- https://github.com/AdguardTeam/AdGuardHome
- https://github.com/kiddin9/kwrt-packages
