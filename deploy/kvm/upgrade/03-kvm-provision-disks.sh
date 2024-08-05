#!/usr/bin/env bash

set -o pipefail

# shellcheck disable=SC1091
source ../config.cfg

# shellcheck disable=SC2153
IMG_NAME=$(basename "$(realpath "$IMAGE_NAME")")
VOL_TEMPLATE="$USER-${IMG_NAME%*.qcow2}"
CONVERT_TO_RAW=1 # always convert to raw

if [ "$CONVERT_TO_RAW" = "1" ]; then
    RAW_SOURCE_IMAGE="${IMAGE_NAME%*.qcow2}.raw"
    if ! [ -f "${RAW_SOURCE_IMAGE}" ]; then
        echo "> converting $IMAGE_NAME to raw format for performance ..."
        qemu-img convert -p "${IMAGE_NAME}" "${RAW_SOURCE_IMAGE}" || {
        echo "> failed to convert to raw format"
        exit 1
    }
    else
       echo "> using existing raw format image ${RAW_SOURCE_IMAGE}"
    fi
fi

if ! virsh vol-list --pool "$STORAGE_POOL" | grep -q "$VOL_TEMPLATE$"; then
    # create a new volume
    IMGSIZE=$(qemu-img info --output json "$RAW_SOURCE_IMAGE" | jq -r '.["virtual-size"]')
    IMGFMT=$(qemu-img info --output json "$RAW_SOURCE_IMAGE" | jq -r .format)

    echo "> creating template volume from $RAW_SOURCE_IMAGE size $IMGSIZE format $IMGFMT"
    virsh vol-create-as "$STORAGE_POOL" "$VOL_TEMPLATE" "$IMGSIZE" --format "$IMGFMT"
    virsh vol-list --pool "$STORAGE_POOL" --details

    echo "> uploading source image to storage pool..."
    virsh vol-upload --pool "$STORAGE_POOL" "$VOL_TEMPLATE" "${RAW_SOURCE_IMAGE}"
    virsh vol-list --pool "$STORAGE_POOL" --details
else
    echo "> using existing image volume template $VOL_TEMPLATE"
fi

# libvirt/virsh locks the pool when doing these operations even if they are
# parallel *sigh* so sequential clone for now
# clone the APPD_IMAGE for this vm
for VM_ID in 1 2 3; do
    VM_NAME_VAR="VM_NAME_${VM_ID}"
    VM_NAME="${!VM_NAME_VAR}"
    echo "> cloning ${VOL_TEMPLATE} for ${VM_NAME}..."
    virsh vol-clone "${VOL_TEMPLATE}" --pool "$STORAGE_POOL" --newname "${VOL_TEMPLATE}-${VM_NAME}"
    # resize cloned volume
    echo "> resizing ${VOL_TEMPLATE}-${VM_NAME} to ${VM_OS_DISK}G ..."
    virsh vol-resize "${VOL_TEMPLATE}-${VM_NAME}" "${VM_OS_DISK}G" --pool "$STORAGE_POOL"
    virsh vol-list --pool "$STORAGE_POOL" --details
done
exit 0
