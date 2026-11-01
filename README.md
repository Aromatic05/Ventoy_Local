# Ventoy_Local - 自定义分区格式与部署的引导工具

> 原版 Ventoy 项目说明：[README_Upstream.md](README_Upstream.md)（保留原始 README）。

[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

## 项目简介

本项目是基于 [Ventoy](https://www.ventoy.net/) 的修改版本，主要针对分区格式和部署方式进行了自定义调整。以下是主要的修改内容：

当前源码已同步上游 Ventoy **1.1.18**（2026-10-09）；CI 打包沿用 `INSTALL/grub/grub.cfg` 中的版本，不再使用时间戳替换。此前已验收的 Release 与本次源码升级相互独立。

1. **移除了对分区格式的强制要求**：原版 Ventoy 对分区格式有严格限制，本版本允许在更多分区格式上使用。
2. **默认使用第一分区、允许独立指定来源**：保留原有部署默认值，GRUB 菜单可分别指定 ISO 所在分区和 Ventoy 运行资源目录。
3. **去除了对引导扇区的校验**：原版 Ventoy 会对引导扇区进行校验，本版本移除了这一限制，允许更灵活的手动部署。
4. **支持手动部署**：用户可以根据需求手动部署 Ventoy，而无需依赖自动化工具。

## 适用场景

- 需要在非标准分区格式上使用 Ventoy。
- 需要在第一分区以外放置 ISO 或运行资源。
- 需要手动控制 Ventoy 的部署过程。
- 对引导扇区有特殊需求的用户。

## 使用方法

### 1. 克隆本仓库

```bash
git clone https://github.com/symwww/Ventoy_Local.git
cd Ventoy_Local
```

### 2. 按照Ventoy官方版构建

得到ventoy.img.xz后解压得到ventoy本体。未指定额外变量时仍按原有第一分区默认方式部署。

EFI/BOOT/grubia32_real.efi

EFI/BOOT/grubx64_real.efi

分别为32/64位下的UEFI引导文件。

grub/i386-pc/core.img

为LeagcyBIOS下的引导文件，请自行使用。

### 3. 独立指定 ISO 与运行资源（源码开发版）

以下是进入特别版 `grub.cfg` 之前设置的 GRUB 环境变量示例（不是系统命令行参数）：

```grub
set VTOY_ISO_SOURCE='(hd2,gpt4)'
set VTOY_RUNTIME_PATH='(hd0,gpt1)/ventoy'
export VTOY_ISO_SOURCE VTOY_RUNTIME_PATH
configfile (hd0,gpt1)/grub/grub.cfg
```

- `VTOY_ISO_SOURCE` 是 ISO 文件所在分区，`grub.cfg` 会以它作为初始浏览和菜单扫描位置；不指定时保持原有默认值。交互式磁盘浏览器仍可选择其他分区。
- `VTOY_RUNTIME_PATH` 是包含 `ventoy.cpio`、`ventoy_x64.efi`、`iso9660_x64.efi` 等运行文件的目录，允许与 ISO 分区不同；不指定时使用原有启动位置。
- 对需要额外 EFI 文件系统驱动的启动模式，显式指定来源后由 GRUB 从 Runtime 目录将驱动加载至内存，再交给 EFI Consumer。BIOS 入口仍需遵守平台自身的加载条件。
- 源码中的 512 字节 `ventoy_os_param` 结构没有改变；磁盘识别维持 GUID、MBR Signature、容量的尽力而为查找，但歧义未消除时拒绝随意选择磁盘。
- 以上功能目前仅完成源码修改和静态检查，不代表已通过完整构建、QEMU 或实机启动验收；已验收的二进制 Release 不受本轮代码修改影响。

## 改动内容

```c
// GRUB2/MOD_SRC/grub-2.04/grub-core/ventoy/ventoy_browser.c 
static int ventoy_browser_iterate_partition(struct grub_disk *disk, const grub_partition_t partition, void *data);

// GRUB2/MOD_SRC/grub-2.04/grub-core/ventoy/ventoy_cmd.c
static int ventoy_set_check_result(int ret, const char *msg);
static int ventoy_check_official_device(grub_device_t dev);
    // 以及调整一些 VTOY_CMD_CHECK(1);

// EDK2/edk2_mod/edk2-edk2-stable201911/MdeModulePkg/Application/Ventoy/Ventoy.c
STATIC VOID ventoy_warn_invalid_device(VOID);
STATIC EFI_STATUS EFIAPI ventoy_find_iso_disk(IN EFI_HANDLE ImageHandle);
STATIC EFI_STATUS EFIAPI ventoy_parse_cmdline(IN EFI_HANDLE ImageHandle);

// Patch vtoyjump (required for Windows/WinPE ISOs)
// vtoyjump/vtoyjump/vtoyjump.c
static int DecompressInjectionArchive(const char *archive, DWORD PhyDrive);
static BOOL CheckVentoyDisk(DWORD DiskNum);
static int VentoyHook(ventoy_os_param *param);
 if (DiskSig == VtoySig) //  && VtoyDiskExtent.StartingOffset.QuadPart == SIZE_1MB
 {
     Log("Ventoy Disk Sig match");
     vtoyfind = TRUE;
     break;
 }

// Patch vtoyjump (required for Linux ISOs)
// VtoyTool/vtoydump.c
static int vtoy_vlnk_printf(ventoy_os_param *param, char *diskname);
static int vtoy_print_os_param(ventoy_os_param *param, char *diskname);
    // 已移除仅用于诊断的第一分区大小检查；改为使用独立磁盘身份匹配。
```

## 注意事项

- 本版本不强制使用 Ventoy 原版分区布局。引导固件自身的 BIOS/UEFI 约束仍然有效。
- 手动部署需要一定的技术知识，请谨慎操作。
- 本版本基于 Ventoy 原版代码修改，可能存在未测试的边缘情况。

## 已知问题

- 多磁盘同时复制了 GUID / MBR Signature，且容量等信息也无法消歧时，可能无法自动定位 ISO 所在磁盘；不会随意选择其中一个。

## 致谢

- 感谢 [Ventoy](https://www.ventoy.net/) 项目的开发者提供了优秀的开源工具。
- 感谢所有贡献者和用户的支持。
