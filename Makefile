BINARY_NAME = StartupBoard
VERSION     = 1.1.0
VOLUME_NAME = StartupBoard

APP  = build/$(BINARY_NAME).app
BIN  = build/$(BINARY_NAME)
DMG  = build/$(BINARY_NAME)-$(VERSION).dmg
STAGING = build/dmg

SOURCES = $(wildcard Sources/StartupBoard/*.swift) $(wildcard Sources/StartupBoard/Views/*.swift)
ICON_PNG  = Resources/AppIcon.png
ICON_ICNS = Resources/AppIcon.icns
ICONSET   = build/AppIcon.iconset

# 可通过环境变量覆盖，例如：
#   make app SDK=/path/to/MacOSX14.sdk ARCH=x86_64 DEPLOYMENT_TARGET=14.0
SDK ?= $(shell xcrun --show-sdk-path 2>/dev/null)
SDK_FLAG = $(if $(SDK),-sdk $(SDK),)

ARCH ?= $(shell uname -m)
DEPLOYMENT_TARGET ?= 14.0
TARGET_FLAG = -target $(ARCH)-apple-macos$(DEPLOYMENT_TARGET)

# 分发给他人时的通用二进制架构（Apple Silicon + Intel）
ARCHS ?= arm64 x86_64
BIN_UNIVERSAL = build/$(BINARY_NAME)-universal
ARCH_DIR = build/arch

# 部分机器的 Command Line Tools 曾出现新旧文件混装（usr/include/swift 下同时存在
# module.modulemap 与 bridging.modulemap），编译时报 "redefinition of module 'SwiftBridging'"。
# 这里用 VFS overlay 把多余的那个文件映射为空来规避：不需要 sudo，也不修改系统文件。
# 仅在检测到两份文件同时存在时启用。
SWIFT_INC  ?= /Library/Developer/CommandLineTools/usr/include/swift
SWIFT_MAPS  = $(wildcard $(SWIFT_INC)/module.modulemap) $(wildcard $(SWIFT_INC)/bridging.modulemap)
VFS_DIR     = build/vfs
VFS_FLAG    = $(if $(filter 2,$(words $(SWIFT_MAPS))),-vfsoverlay $(CURDIR)/$(VFS_DIR)/overlay.yaml,)
VFS_DEPS    = $(if $(VFS_FLAG),$(VFS_DIR)/overlay.yaml,)

# 未提供 Developer ID 时使用 ad-hoc 签名（自编译足够；对外分发需自行公证）
SIGN_IDENTITY ?= -

.PHONY: all help build app universal icon run dmg clean

all: app

help:
	@echo "make app       编译并打包为 $(APP)（当前架构）"
	@echo "make universal 编译双架构（$(ARCHS)）并打包为 $(APP)"
	@echo "make run       打包后直接运行"
	@echo "make icon      重新生成图标（$(ICON_PNG) + $(ICON_ICNS)）"
	@echo "make dmg       生成可分发的 $(DMG)（自动使用通用二进制）"
	@echo "make clean     清理 build/ 目录"
	@echo ""
	@echo "环境变量：SDK | ARCH | ARCHS | DEPLOYMENT_TARGET | SIGN_IDENTITY"

build: $(BIN)

$(BIN): $(SOURCES) $(VFS_DEPS)
	@mkdir -p build
	swiftc $(SDK_FLAG) $(TARGET_FLAG) $(VFS_FLAG) -parse-as-library -O -o $(BIN) $(SOURCES)

$(ARCH_DIR)/%: $(SOURCES) $(VFS_DEPS)
	@mkdir -p "$(ARCH_DIR)"
	swiftc $(SDK_FLAG) -target $*-apple-macos$(DEPLOYMENT_TARGET) $(VFS_FLAG) -parse-as-library -O -o $@ $(SOURCES)

$(BIN_UNIVERSAL): $(addprefix $(ARCH_DIR)/,$(ARCHS))
	lipo -create $^ -output $@

$(VFS_DIR)/overlay.yaml:
	@mkdir -p "$(VFS_DIR)"
	@: > "$(VFS_DIR)/empty.modulemap"
	@printf "{\n  'version': 0,\n  'case-sensitive': 'false',\n  'use-external-names': 'false',\n  'roots': [\n    {\n      'type': 'file',\n      'name': '$(SWIFT_INC)/module.modulemap',\n      'external-contents': '$(CURDIR)/$(VFS_DIR)/empty.modulemap'\n    }\n  ]\n}\n" > "$(VFS_DIR)/overlay.yaml"

# MARK: - 图标（透明背景 PNG → .icns）

icon: $(ICON_ICNS)

$(ICON_PNG): Tools/MakeIcon.swift
	@mkdir -p build
	swiftc $(SDK_FLAG) $(VFS_FLAG) -O -o build/make-icon Tools/MakeIcon.swift
	./build/make-icon Resources

$(ICON_ICNS): $(ICON_PNG)
	rm -rf "$(ICONSET)"
	mkdir -p "$(ICONSET)"
	sips -z 16 16 "$(ICON_PNG)" --out "$(ICONSET)/icon_16x16.png" >/dev/null
	sips -z 32 32 "$(ICON_PNG)" --out "$(ICONSET)/icon_16x16@2x.png" >/dev/null
	sips -z 32 32 "$(ICON_PNG)" --out "$(ICONSET)/icon_32x32.png" >/dev/null
	sips -z 64 64 "$(ICON_PNG)" --out "$(ICONSET)/icon_32x32@2x.png" >/dev/null
	sips -z 128 128 "$(ICON_PNG)" --out "$(ICONSET)/icon_128x128.png" >/dev/null
	sips -z 256 256 "$(ICON_PNG)" --out "$(ICONSET)/icon_128x128@2x.png" >/dev/null
	sips -z 256 256 "$(ICON_PNG)" --out "$(ICONSET)/icon_256x256.png" >/dev/null
	sips -z 512 512 "$(ICON_PNG)" --out "$(ICONSET)/icon_256x256@2x.png" >/dev/null
	sips -z 512 512 "$(ICON_PNG)" --out "$(ICONSET)/icon_512x512.png" >/dev/null
	cp "$(ICON_PNG)" "$(ICONSET)/icon_512x512@2x.png"
	iconutil -c icns "$(ICONSET)" -o "$(ICON_ICNS)"
	rm -rf "$(ICONSET)"
	@echo "已生成 $(ICON_ICNS)"

# MARK: - 打包

# 用指定可执行文件组装 .app 包并签名
define assemble_app
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(1)" "$(APP)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp "$(ICON_ICNS)" "$(APP)/Contents/Resources/AppIcon.icns"
	-codesign --force --sign "$(SIGN_IDENTITY)" "$(APP)" >/dev/null 2>&1
endef

app: build icon
	$(call assemble_app,$(BIN))
	@echo "已生成 $(APP)，可执行 make run 启动"

# 双架构版本：Apple Silicon 与 Intel 都能运行，用于分发给他人
universal: $(BIN_UNIVERSAL) icon
	$(call assemble_app,$(BIN_UNIVERSAL))
	@echo "已生成 $(APP)（通用二进制：$(ARCHS)）"

run: app
	open "$(APP)"

# 打包为 dmg（内含 app 与 /Applications 快捷方式，拖动即可安装）
dmg: universal
	rm -rf "$(STAGING)" "$(DMG)"
	mkdir -p "$(STAGING)"
	ditto "$(APP)" "$(STAGING)/$(BINARY_NAME).app"
	ln -s /Applications "$(STAGING)/Applications"
	hdiutil create -volname "$(VOLUME_NAME)" -srcfolder "$(STAGING)" -ov -format UDZO "$(DMG)"
	rm -rf "$(STAGING)"
	@echo "已生成 $(DMG)"

clean:
	rm -rf build
