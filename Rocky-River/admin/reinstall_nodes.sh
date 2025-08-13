#!/bin/bash

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件"

    if [ ! -e new_install.nodes ]; then
        log_error "new_install.nodes 文件不存在，请先执行 add_computenode.sh 添加节点"
    fi

    if ! command -v pdsh >/dev/null 2>&1; then
        log_error "pdsh 命令未找到，请确保已安装并配置 xCAT 环境"
    fi
}


# 检查参数
check_arguments() {
    log_info "检查参数"
    
    if [ -z "$1" ]; then
        log_warn "未输入节点信息，请提供节点名称作为参数，支持xcat节点写法,例如"
        log_info "cnode001"
        log_info "cnode001,cnode002"
        log_info "cnode[001-100]"
        log_info "cnode001,cnode[006-100]"
        exit 1
    fi
    
    if [ "$#" -gt 1 ]; then
        log_error "只有一个参数，多参数无效"
    fi
    
    node_name="$1"
    echo "将要重装以下节点："
    nodelist $node_name
    if [ $? -ne 0 ]; then
        log_error "节点 $node_name 不存在"
        exit 1
    fi
    nodelist=$(nodelist $node_name)

}

# 重装节点确认
confirm_node_reinstall() {
    log_info "重装节点确认"
    
    read -p "是否需要重装节点 $node_name ：(y/n)  " ichoice
    if [[ "$ichoice" != "y" ]]; then
        log_info "取消重装操作"
        exit 0
    fi
}

# 重装节点
reinstall_node() { 
    local default_deploy_config=$(osdeploy list| grep default | sed 's/ //g')
    local mydefinition_config=${default_deploy_config/default/mydefinition}
    # 其他设置：
    nodedeploy -n $node_name -p ${mydefinition_config}
}

main() {
    log_info "开始重装节点 $node_name"

    check_prerequisites


    check_arguments

    confirm_node_reinstall

    reinstall_node

    log_info "重装节点 $node_name 设置完成，请在节点安装完毕后运行:"
    log_info "sh ./admin/after_add_nodes.sh $node_name"

}