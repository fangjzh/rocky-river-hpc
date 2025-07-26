#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi


# 验证集群名称
validate_cluster_name() {
    local name="$1"
    
    # 检查长度
    if [ ${#name} -lt 4 ] || [ ${#name} -gt 10 ]; then
        log_error "集群名称长度必须在4-10个字符之间"
        return 1
    fi
    
    # 检查是否以字母开头
    if ! echo "$name" | grep -qE '^[a-zA-Z]'; then
        log_error "集群名称必须以字母开头"
        return 1
    fi
    
    # 检查是否包含非法字符
    if ! echo "$name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        log_error "集群名称包含非法字符，只能包含字母、数字、下划线(_)和连字符(-)"
        return 1
    fi
    
    return 0
}

# 主函数
reg_name() {
    local cname=""
    
    while true; do
        echo "请输入集群名字，4-10个英文字符（只能包含字母、数字、下划线和连字符，且必须以字母开头）："
        read cname
        
        if validate_cluster_name "$cname"; then
            break
        fi
        
        echo "请重新输入。"
        echo
    done
    
    log_info "你的集群名为：$cname"
    echo "## 集群名：" >>env.text
    echo "export sms_name=$cname" >>env.text
}

# 执行主函数
reg_name