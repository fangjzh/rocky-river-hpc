#!/bin/bash

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

# 查找文件函数
find_file() {
    local filename="$1"
    local search_paths=("/root" "/mnt" "/media" "/run/media")
    local res=()

    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            res+=("$(find "$path" -name "$filename" 2>/dev/null)")
        fi
    done

    if [ -z "${res[0]}" ]; then
        return 1
    else
        echo "$(realpath "${res[0]}")"
        return 0
    fi
}

# 主函数
findpackage() {
    # 检查参数
    if [ -z "$1" ]; then
        log_error "必须提供 iso_name 作为参数"
    fi

    local iso_name="$1"
    local package_dir=""
    local iso_path=""

    # 查找 ISO 文件
    local iso_file_path=$(find_file "$iso_name")
    if [ $? -ne 0 ]; then
        log_error "没有找到系统镜像 $iso_name！请将镜像放到 /root、/mnt、/media 或 /run/media 目录下！"
    fi
    iso_path=$(dirname "$iso_file_path")

    # 查找 dep-packages.tar
    local package_file_path=$(find_file "confluent.tar")
    if [ $? -ne 0 ]; then
        log_error "没有找到安装包文件 dep-packages.tar！请将文件放到 /root、/mnt、/media 或 /run/media 目录下！"
    fi
    package_dir=$(dirname "$package_file_path")

    # 验证所有安装包是否存在
    local filelist=(
        dep-packages.tar
        kickstart-crb.tar
        openhpc.tar
        xcat.tar
        confluent.tar
    )

    for ifile in "${filelist[@]}"; do
        if [ ! -e "${package_dir}/${ifile}" ]; then
            log_error "安装包 ${ifile} 不存在!!!"
        fi
    done

    # 写入环境变量到 env.text
    echo "### 安装文件位置：" >>env.text
    echo "export package_dir=${package_dir}" >>env.text
    echo "export iso_path=${iso_path}" >>env.text
    echo "export iso_name=${iso_name}" >>env.text

    log_info "安装文件已全部找到！"
}

# 执行主函数
findpackage "$@"