#!/bin/bash
#
# Compile script for OnePlus 12 kernel
# SPDX-FileCopyrightText: Adithya R.
# SPDX-FileCopyrightText: YumeMichi
#

SECONDS=0 # start builtin bash timer
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TC_DIR="$HOME/Workspace/android/clang"
OUT_DIR="$ROOT_DIR/out"

DO_CLEAN=false
TARGET=waffle
PLATFORM=pineapple

if (( $# == 0 )); then
    echo "Usage: $0 <device-kernel-directory> [--clean]" >&2
    exit 2
fi

DEVICE_KERNEL_DIR="$1"
shift
if [ ! -d "$DEVICE_KERNEL_DIR" ]; then
    echo "Output kernel directory does not exist: $DEVICE_KERNEL_DIR" >&2
    exit 1
fi
DEVICE_KERNEL_DIR="$(cd -- "$DEVICE_KERNEL_DIR" && pwd -P)"

while (( $# > 0 )); do
    case "$1" in
        -c|--clean) DO_CLEAN=true ;;
        -h|--help)
            echo "Usage: $0 <device-kernel-directory> [--clean]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 <device-kernel-directory> [--clean]" >&2
            exit 2
            ;;
    esac
    shift
done

export KBUILD_BUILD_USER=nobody
export KBUILD_BUILD_HOST=android-build
export BRANCH=android14-6.1
export KMI_GENERATION=11

DEFCONFIGS="gki_defconfig \
    vendor/pineapple_GKI.config \
    vendor/oplus/pineapple_GKI.config"

MODULES_SRC="sm8650-modules"
MODULES="qcom/opensource/mmrm-driver \
    qcom/opensource/mm-drivers/hw_fence \
    qcom/opensource/mm-drivers/msm_ext_display \
    qcom/opensource/mm-drivers/sync_fence \
    qcom/opensource/securemsm-kernel \
    qcom/opensource/audio-kernel \
    qcom/opensource/synx-kernel \
    qcom/opensource/camera-kernel \
    qcom/opensource/datarmnet-ext/mem \
    qcom/opensource/dataipa/drivers/platform/msm \
    qcom/opensource/datarmnet/core \
    qcom/opensource/datarmnet-ext/aps \
    qcom/opensource/datarmnet-ext/offload \
    qcom/opensource/datarmnet-ext/shs \
    qcom/opensource/datarmnet-ext/perf \
    qcom/opensource/datarmnet-ext/perf_tether \
    qcom/opensource/datarmnet-ext/sch \
    qcom/opensource/datarmnet-ext/wlan \
    qcom/opensource/display-drivers/msm \
    qcom/opensource/dsp-kernel \
    qcom/opensource/eva-kernel \
    qcom/opensource/video-driver \
    qcom/opensource/graphics-kernel \
    qcom/opensource/wlan/platform \
    qcom/opensource/wlan/qcacld-3.0/.kiwi_v2 \
    qcom/opensource/wlan/qcacld-3.0/.qca6750 \
    qcom/opensource/bt-kernel \
    qcom/opensource/spu-kernel \
    qcom/opensource/mm-sys-kernel/ubwcp \
    nxp/opensource/driver"

# Oplus' vendor_dlkm drivers are not part of the kernel's in-tree module
# targets.  Most of these directories contain Kbuild fragments only (rather
# than a standalone `modules:` wrapper), so they must be built with M= from
# the kernel top level.  Keep aggregate directories here; their own Kbuild
# files recurse into the chip/feature subdirectories.
OPLUS_MODULES="oplus/kernel/touchpanel/oplus_touchscreen_v2/touch_custom \
    oplus/kernel/touchpanel/oplus_touchscreen_v2 \
    oplus/kernel/touchpanel/synaptics_hbp \
    oplus/kernel/tp/hbp/hbp \
    oplus/kernel/touchpanel/kernelFwUpdate \
    oplus/kernel/touchpanel/touchpanel_notify \
    oplus/kernel/audio \
    oplus/kernel/boot \
    oplus/kernel/charger \
    oplus/kernel/cpu/thermal \
    oplus/kernel/device_info/pogo_keyboard \
    oplus/kernel/device_info/tri_state_key \
    oplus/kernel/dfr \
    oplus/kernel/dft \
    oplus/kernel/graphics \
    oplus/kernel/multimedia/feedback \
    oplus/kernel/network/oplus_network_oem_qmi \
    oplus/kernel/network/oplus_network_esim \
    oplus/kernel/network/oplus_network_sim_detect \
    oplus/kernel/network/oplus_rf_cable_monitor \
    oplus/kernel/vibrator/aw8697_haptic \
    oplus/kernel/vibrator/oplus_haptic \
    oplus/kernel/vibrator/si_haptic \
    oplus/secure/biometrics/fingerprints/bsp/uff/driver \
    oplus/secure/common/bsp/drivers \
    oplus/sensor/kernel/oplus_consumer_ir \
    oplus/sensor/kernel/qcom/sensor \
    oplus/hardware/radio/kernel"

DT_OUTPUT_DIR="$OUT_DIR/arch/arm64/boot/dts/vendor"
DT_BASE_DIR="$OUT_DIR/dtbs-base"
DT_TECHPACK_DIR="$OUT_DIR/dtbs-techpack"
DT_MERGED_DIR="$OUT_DIR/dtbs"

export PATH="$TC_DIR/bin:$ROOT_DIR/scripts/dtc/libfdt:$PATH"
if [ -x "$ROOT_DIR/../oplus_kernel_platform/out/host/bin/fdtoverlaymerge" ]; then
    export PATH="$ROOT_DIR/../oplus_kernel_platform/out/host/bin:$PATH"
fi

msg() {
    echo -e "\e[1;32m$1\e[0m"
}

m() {
    make -j$(nproc --all) O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 \
        KERNEL_SRC="$ROOT_DIR" OUT_DIR="$OUT_DIR" \
        DTC_EXT="$(command -v dtc)" \
        DTC_OVERLAY_TEST_EXT="$ROOT_DIR/scripts/dtc/libfdt/ufdt_apply_overlay" \
        TARGET_PRODUCT=$TARGET TARGET_BOARD_PLATFORM=$PLATFORM \
        CONFIG_OPLUS_DEVICE_DTBS=y CONFIG_WAFFLE_DTB=y "$@" || exit $?
}

clean_module_cmd_cache() {
    local module_out="$1"
    [ -d "$module_out" ] || return 0

    while IFS= read -r cmd_file; do
        if [ "$(wc -l < "$cmd_file")" -ne 1 ] || \
           ! sed -n '1s/^cmd_[^ ]* := .*/ok/p' "$cmd_file" | grep -q '^ok$'; then
            rm -f "$cmd_file"
        fi
    done < <(find "$module_out" -type f -name '.modules.order.cmd' -print)
}

$DO_CLEAN && {
    rm -rf "$OUT_DIR"
    echo "Cleaned output directories."
}

echo -e "Generating config...\n"
mkdir -p "$OUT_DIR"
m $DEFCONFIGS
# m ./scripts/kconfig/merge_config.sh $DEFCONFIGS

msg "\nBuilding kernel...\n"
# The DT output tree is generated data.  Clear it before dtbs so that files
# from another product or an older configuration cannot enter the merge.
rm -rf "$DT_OUTPUT_DIR"
m Image modules dtbs 2> >(tee "$OUT_DIR/error.log" >&2)
rm -rf "$OUT_DIR/modules" "$OUT_DIR"/*.ko
m INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install 2> >(tee "$OUT_DIR/error.log" >&2)

msg "\nBuilding techpack modules..."
for module in $MODULES; do
    msg "\nBuilding $module..."
    module_rel="$MODULES_SRC/$module"
    module_dir="$ROOT_DIR/$module_rel"
    module_out="$OUT_DIR/$module_rel"

    # .cmd files are generated Makefile fragments.  A previously interrupted
    # or in-tree module build can leave a malformed modules.order cache here;
    # remove only that generated cache before entering the external build.
    clean_module_cmd_cache "$module_out"

    module_args=(-C "$module_dir" M="$module_rel" KERNEL_SRC="$ROOT_DIR" OUT_DIR="$OUT_DIR")
    m "${module_args[@]}"
    m "${module_args[@]}" \
        INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install 2> >(tee "$OUT_DIR/error.log" >&2)
done

msg "\nBuilding Oplus vendor_dlkm modules..."
for module_rel in $OPLUS_MODULES; do
    msg "\nBuilding $module_rel..."
    module_path="$MODULES_SRC/$module_rel"
    module_out="$OUT_DIR/$module_path"
    clean_module_cmd_cache "$module_out"

    # These are pure Kbuild external modules.  Invoking make -C in the module
    # directory treats its Makefile as a top-level makefile and fails for
    # directories without a `modules:` target (and can create malformed
    # modules.order.cmd files).  M= makes the kernel build system consume the
    # fragment from the correct top-level context.
    module_config=()
    if [ "$module_rel" = "oplus/secure/common/bsp/drivers" ]; then
        # The standalone secure-common wrapper normally supplies these
        # symbols through KBUILD_OPTIONS.  We invoke its parent Kbuild
        # directly, so pass the Qcom module configuration explicitly.
        module_config=(
            CONFIG_OPLUS_SECURE_COMMON=m
            CONFIG_OPLUS_SECURE_QCOM=y
            OPLUS_OUT_OF_TREE_KO=y
        )
    fi

    m M="$module_path" "${module_config[@]}" modules
    m M="$module_path" "${module_config[@]}" \
        INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install \
        2> >(tee "$OUT_DIR/error.log" >&2)
done

msg "\nKernel compiled succesfully!\nMerging dtb's...\n"

if [ ! -d "$DT_OUTPUT_DIR" ]; then
    echo "DT output directory was not generated: $DT_OUTPUT_DIR" >&2
    exit 1
fi

rm -rf "$DT_BASE_DIR" "$DT_TECHPACK_DIR" "$DT_MERGED_DIR" || exit 1
mkdir -p "$DT_BASE_DIR" "$DT_TECHPACK_DIR" "$DT_MERGED_DIR" || exit 1

# Oplus's DT merge flow treats the six platform DTBs and the six Oplus board
# overlays as bases.  All other DTBOs are techpack overlays.  This is
# important: feeding the Oplus overlays to the techpack side produces only
# the six platform DTBs and loses the final board-specific DTBOs.
base_count=0
while IFS= read -r -d '' dtb; do
    cp "$dtb" "$DT_BASE_DIR/" || exit 1
    base_count=$((base_count + 1))
done < <(find "$DT_OUTPUT_DIR/qcom" -maxdepth 1 -type f -name '*.dtb' -print0 2>/dev/null)

while IFS= read -r -d '' dtbo; do
    cp "$dtbo" "$DT_BASE_DIR/" || exit 1
    base_count=$((base_count + 1))
done < <(find "$DT_OUTPUT_DIR/oplus" -maxdepth 1 -type f -name '*.dtbo' -print0 2>/dev/null)

if [ "$base_count" -eq 0 ]; then
    echo "No base DTBs found under $DT_OUTPUT_DIR/qcom" >&2
    exit 1
fi

# Keep techpack DTBO subdirectories intact.  Their relative paths are used by
# humans when debugging and also make this staging tree match LineageOS output.
dtbo_count=0
while IFS= read -r -d '' dtbo; do
    relative_path="${dtbo#"$DT_OUTPUT_DIR/"}"
    destination="$DT_TECHPACK_DIR/$relative_path"
    mkdir -p "$(dirname "$destination")" || exit 1
    cp "$dtbo" "$destination" || exit 1
    dtbo_count=$((dtbo_count + 1))
done < <(find "$DT_OUTPUT_DIR" -type f -name '*.dtbo' -print0)

# The six Oplus board overlays are consumed as merge bases above, so remove
# them from the techpack staging tree before running merge_dtbs.py.
while IFS= read -r -d '' dtbo; do
    rm -f "$DT_TECHPACK_DIR/${dtbo#"$DT_OUTPUT_DIR/"}"
done < <(find "$DT_OUTPUT_DIR/oplus" -maxdepth 1 -type f -name '*.dtbo' -print0 2>/dev/null)

if [ "$dtbo_count" -eq 0 ]; then
    echo "Warning: no techpack DTBOs found under $DT_OUTPUT_DIR" >&2
fi

msg "Collected $base_count base DTBs and $dtbo_count techpack DTBOs."
python3 "$ROOT_DIR/merge_dtbs.py" \
    -b "$DT_BASE_DIR" \
    -t "$DT_TECHPACK_DIR" \
    -o "$DT_MERGED_DIR" || exit $?

msg "Installing kernel headers\n"
m headers_install
# Keep the kernel's sigaction private so bionic can expose its POSIX version.
sigaction_header="$OUT_DIR/usr/include/asm-generic/signal.h"
sigaction_backup="${sigaction_header}.orig"
if [ ! -f "$sigaction_header" ]; then
    echo "Missing exported header: $sigaction_header" >&2
    exit 1
fi
# Do not retain or export a backup from an earlier header patch.
rm -f "$sigaction_backup"
if ! grep -q '^struct __kernel_sigaction {' "$sigaction_header"; then
    sed -i 's/^struct sigaction {/struct __kernel_sigaction {/' "$sigaction_header" || exit $?
fi
rm -f "$sigaction_backup"
if ! grep -q '^struct __kernel_sigaction {' "$sigaction_header"; then
    echo "Failed to rename sigaction in $sigaction_header" >&2
    exit 1
fi

msg "\nExporting kernel artifacts...\n"

if [ ! -f "$OUT_DIR/include/config/kernel.release" ]; then
    echo "Missing kernel.release: $OUT_DIR/include/config/kernel.release" >&2
    exit 1
fi

KERNEL_RELEASE="$(<"$OUT_DIR/include/config/kernel.release")"
MODULES_ROOT="$OUT_DIR/modules/lib/modules/$KERNEL_RELEASE"
# Keep the exported system_dlkm path stable across vendor-only commits.  The
# actual KERNEL_RELEASE is still used for the build output, vermagic, and
# depmod input tree above.
SYSTEM_MODULES_RELEASE="android14-6.1"
if [ ! -d "$MODULES_ROOT" ]; then
    echo "Missing installed modules: $MODULES_ROOT" >&2
    exit 1
fi

# CONFIG_MODULE_SIG_ALL is intentionally disabled in the GKI/device config.
# Sign only modules assigned to system_dlkm.  Modules assigned to
# vendor_dlkm/vendor_boot are vendor-owned and may remain unsigned under
# CONFIG_MODULE_SIG_PROTECT=y.
sign_installed_modules() {
    local sign_file="$OUT_DIR/scripts/sign-file"
    local signing_key="$OUT_DIR/certs/signing_key.pem"
    local signing_cert="$OUT_DIR/certs/signing_key.x509"
    local hash_algo
    local system_module_list="$ROOT_DIR/modules.system_dlkm.list.msm.pineapple"
    local module module_name signed_count=0

    hash_algo="$(sed -n 's/^CONFIG_MODULE_SIG_HASH="\{0,1\}\([^" ]*\)"\{0,1\}$/\1/p' \
        "$OUT_DIR/.config")"
    if [ -z "$hash_algo" ]; then
        echo "Missing CONFIG_MODULE_SIG_HASH in $OUT_DIR/.config" >&2
        exit 1
    fi

    if [ ! -x "$sign_file" ] || [ ! -f "$signing_key" ] || [ ! -f "$signing_cert" ]; then
        echo "Missing kernel module signing tools or keys" >&2
        exit 1
    fi
    if [ ! -f "$system_module_list" ]; then
        echo "Missing GKI module list: $system_module_list" >&2
        exit 1
    fi

    while IFS= read -r -d '' module; do
        module_name="${module##*/}"
        if ! grep -Fxq "$module_name" "$system_module_list"; then
            continue
        fi
        # Do not append a second signature if a module was supplied signed by
        # an external Kbuild fragment.
        if tail -c 28 "$module" | grep -Fqx '~Module signature appended~'; then
            continue
        fi
        "$sign_file" "$hash_algo" "$signing_key" "$signing_cert" "$module" || exit $?
        signed_count=$((signed_count + 1))
    done < <(find "$MODULES_ROOT/kernel" -type f -name '*.ko' -print0)

    if [ "$signed_count" -eq 0 ]; then
        echo "No unsigned installed modules were found to sign" >&2
    else
        msg "Signed $signed_count installed GKI module files"
    fi
}

sign_installed_modules

rm -rf "$OUT_DIR/export"
EXPORT_DIR="$OUT_DIR/export"
SYSTEM_DIR="$EXPORT_DIR/system_dlkm/lib/modules/$SYSTEM_MODULES_RELEASE"
VENDOR_DIR="$EXPORT_DIR/vendor_dlkm"
RAMDISK_DIR="$EXPORT_DIR/vendor_ramdisk"
mkdir -p "$EXPORT_DIR/dtbs" "$EXPORT_DIR/kernel-headers" "$SYSTEM_DIR" "$VENDOR_DIR" "$RAMDISK_DIR"

cp "$OUT_DIR/arch/arm64/boot/Image" "$EXPORT_DIR/Image"
cp "$OUT_DIR/Module.symvers" "$EXPORT_DIR/Module.symvers"
cp "$OUT_DIR/System.map" "$EXPORT_DIR/System.map"
cp -a "$OUT_DIR/usr/include/." "$EXPORT_DIR/kernel-headers/"

# audio-kernel exports its UAPI below include/audio/, but Android's kernel
# header modules consume these files directly below kernel-headers/.
if [ -d "$EXPORT_DIR/kernel-headers/audio" ]; then
    cp -a "$EXPORT_DIR/kernel-headers/audio/." "$EXPORT_DIR/kernel-headers/"
    rm -rf "$EXPORT_DIR/kernel-headers/audio"
fi

#cat "$OUT_DIR/dtbs"/*.dtb > "$EXPORT_DIR/dtbs/waffle.dtb"
cp "$OUT_DIR/dtbs"/*.dtb "$EXPORT_DIR/dtbs/"
dtbo_inputs=("$OUT_DIR/dtbs"/*.dtbo)
if [ ! -e "${dtbo_inputs[0]}" ]; then
    echo "No merged DTBOs found in $OUT_DIR/dtbs" >&2
    exit 1
fi
python3 "$ROOT_DIR/mkdtboimg.py" create "$EXPORT_DIR/dtbs/dtbo.img" \
    --page_size=4096 "${dtbo_inputs[@]}"

module_source_for() {
    local module_name="$1"
    local extra_module

    # Some Oplus drivers are present both in the in-tree vendor tree and as
    # separately built external modules.  depmod keeps only one entry for a
    # duplicate module name; prefer the external `extra/` copy because that is
    # the module variant referenced by the vendor/recovery module lists.
    extra_module="$(find "$MODULES_ROOT/extra" -type f -name "$module_name" \
        -printf '%P\n' -quit 2>/dev/null)"
    if [ -n "$extra_module" ]; then
        printf 'extra/%s\n' "$extra_module"
        return 0
    fi

    awk -F: -v module="$module_name" '
        { path = $1; name = path; sub(/^.*\//, "", name); if (name == module) { print path; exit } }
    ' "$MODULES_ROOT/modules.dep"
}

copy_module_list() {
    local list_file="$1"
    local destination="$2"
    local module_name module_path
    while IFS= read -r module_name; do
        [ -n "$module_name" ] || continue
        module_path="$(module_source_for "$module_name")"
        if [ -z "$module_path" ] || [ ! -f "$MODULES_ROOT/$module_path" ]; then
            echo "Missing module listed in $list_file: $module_name" >&2
            exit 1
        fi
        cp "$MODULES_ROOT/$module_path" "$destination/$module_name"
    done < "$ROOT_DIR/$list_file"
}

all_module_names="$EXPORT_DIR/.all-modules"
awk -F: '{ path = $1; sub(/^.*\//, "", path); print path }' "$MODULES_ROOT/modules.dep" > "$all_module_names"
exported_module_count="$(wc -l < "$all_module_names")"
system_module_names="$EXPORT_DIR/.system-modules"
cp "$ROOT_DIR/modules.system_dlkm.list.msm.pineapple" "$system_module_names"

copy_module_list modules.system_dlkm.list.msm.pineapple "$SYSTEM_DIR"
while IFS= read -r module_name; do
    [ -n "$module_name" ] || continue
    if ! grep -Fxq "$module_name" "$system_module_names"; then
        module_path="$(module_source_for "$module_name")"
        cp "$MODULES_ROOT/$module_path" "$VENDOR_DIR/$module_name"
    fi
done < "$all_module_names"
copy_module_list modules.recovery.list.msm.pineapple "$RAMDISK_DIR"
copy_module_list modules.recovery.list.oplus.pineapple "$RAMDISK_DIR"

prepare_depmod_tree() {
    local list_file="$1"
    local stage_dir="$2"
    local module_name module_path
    mkdir -p "$stage_dir/lib/modules/$KERNEL_RELEASE"
    while IFS= read -r module_name; do
        [ -n "$module_name" ] || continue
        module_path="$(module_source_for "$module_name")"
        if [ -z "$module_path" ] || [ ! -f "$MODULES_ROOT/$module_path" ]; then
            echo "Missing module for depmod: $module_name" >&2
            exit 1
        fi
        cp "$MODULES_ROOT/$module_path" "$stage_dir/lib/modules/$KERNEL_RELEASE/$module_name"
    done < "$list_file"
    : > "$stage_dir/lib/modules/$KERNEL_RELEASE/modules.order"
    : > "$stage_dir/lib/modules/$KERNEL_RELEASE/modules.builtin"
    : > "$stage_dir/lib/modules/$KERNEL_RELEASE/modules.builtin.modinfo"
    depmod -b "$stage_dir" "$KERNEL_RELEASE"
}

rewrite_depmod_paths() {
    local input="$1"
    local output="$2"
    local partition="$3"
    awk -v mode="$partition" -v krel="$SYSTEM_MODULES_RELEASE" '
        BEGIN {
            while ((getline module < "'"$ROOT_DIR"'/modules.system_dlkm.list.msm.pineapple") > 0)
                system_modules[module] = 1
            close("'"$ROOT_DIR"'/modules.system_dlkm.list.msm.pineapple")
        }
        function name(path) { sub(/^.*\//, "", path); return path }
        function prefix(module) {
            if (mode == "system") return "/system_dlkm/lib/modules/" krel
            if (mode == "ramdisk") return "/lib/modules"
            if (system_modules[module]) return "/system_dlkm/lib/modules/" krel
            return "/vendor_dlkm/lib/modules"
        }
        {
            module = name($1)
            sub(/:$/, "", module)
            line = prefix(module) "/" module ":"
            for (i = 2; i <= NF; i++) {
                dependency = name($i)
                line = line " " prefix(dependency) "/" dependency
            }
            print line
        }
    ' "$input" > "$output"
}

system_stage="$EXPORT_DIR/.depmod-system"
vendor_stage="$EXPORT_DIR/.depmod-vendor"
ramdisk_stage="$EXPORT_DIR/.depmod-ramdisk"
prepare_depmod_tree "$system_module_names" "$system_stage"
prepare_depmod_tree "$all_module_names" "$vendor_stage"
recovery_module_names="$EXPORT_DIR/.recovery-modules"
cat "$ROOT_DIR/modules.recovery.list.msm.pineapple" "$ROOT_DIR/modules.recovery.list.oplus.pineapple" > "$recovery_module_names"
prepare_depmod_tree "$recovery_module_names" "$ramdisk_stage"

cp "$system_stage/lib/modules/$KERNEL_RELEASE/modules.alias" "$SYSTEM_DIR/modules.alias"
cp "$system_stage/lib/modules/$KERNEL_RELEASE/modules.softdep" "$SYSTEM_DIR/modules.softdep"
rewrite_depmod_paths "$system_stage/lib/modules/$KERNEL_RELEASE/modules.dep" "$SYSTEM_DIR/modules.dep" system
cp "$vendor_stage/lib/modules/$KERNEL_RELEASE/modules.alias" "$VENDOR_DIR/modules.alias"
cp "$vendor_stage/lib/modules/$KERNEL_RELEASE/modules.softdep" "$VENDOR_DIR/modules.softdep"
rewrite_depmod_paths "$vendor_stage/lib/modules/$KERNEL_RELEASE/modules.dep" "$VENDOR_DIR/modules.dep" vendor
cp "$ramdisk_stage/lib/modules/$KERNEL_RELEASE/modules.alias" "$RAMDISK_DIR/modules.alias"
cp "$ramdisk_stage/lib/modules/$KERNEL_RELEASE/modules.softdep" "$RAMDISK_DIR/modules.softdep"
rewrite_depmod_paths "$ramdisk_stage/lib/modules/$KERNEL_RELEASE/modules.dep" "$RAMDISK_DIR/modules.dep" ramdisk

rm -rf "$EXPORT_DIR/.all-modules" "$EXPORT_DIR/.system-modules" \
       "$EXPORT_DIR/.recovery-modules" "$system_stage" "$vendor_stage" "$ramdisk_stage"
cp "$ROOT_DIR/modules.vendor_blocklist.msm.pineapple" "$VENDOR_DIR/modules.blocklist"
cp "$ROOT_DIR/modules.vendor_blocklist.msm.pineapple" "$RAMDISK_DIR/modules.blocklist"
cp "$ROOT_DIR/modules.systemdlkm_blocklist.msm.pineapple" "$VENDOR_DIR/system_dlkm.modules.blocklist"
cat "$ROOT_DIR/modules.system_dlkm.list.msm.pineapple" > "$SYSTEM_DIR/modules.load"
cat "$ROOT_DIR/modules.vendor_dlkm.list.msm.pineapple" "$ROOT_DIR/modules.vendor_dlkm.list.oplus.pineapple" > "$VENDOR_DIR/modules.load"
cat "$ROOT_DIR/modules.vendor_boot.list.msm.pineapple" "$ROOT_DIR/modules.vendor_boot.list.oplus.pineapple" > "$RAMDISK_DIR/modules.load"
cat "$ROOT_DIR/modules.recovery.list.msm.pineapple" "$ROOT_DIR/modules.recovery.list.oplus.pineapple" > "$RAMDISK_DIR/modules.load.recovery"

# The export contains deployable artifacts only; compiler dependency caches
# such as .cmd files must never enter the device repository.
find "$EXPORT_DIR" -type f -name '*.cmd' -delete

if [ ! -f "$DEVICE_KERNEL_DIR/Android.bp" ]; then
    echo "Missing Android.bp in $DEVICE_KERNEL_DIR" >&2
    exit 1
fi

find "$DEVICE_KERNEL_DIR" -mindepth 1 -maxdepth 1 \
    ! -name .git ! -name Android.bp -exec rm -rf -- {} +
if ! cp -a "$EXPORT_DIR/." "$DEVICE_KERNEL_DIR/"; then
    echo "Failed to export kernel artifacts to $DEVICE_KERNEL_DIR" >&2
    exit 1
fi

msg "Exported kernel release $KERNEL_RELEASE (system_dlkm path: $SYSTEM_MODULES_RELEASE)"
msg "Exported $exported_module_count unique installed module names"
