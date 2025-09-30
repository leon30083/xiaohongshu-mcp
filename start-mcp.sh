#!/bin/bash
# 🚀 小红书MCP服务器启动脚本 (Linux/macOS)
# Author: AI Assistant

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 输出函数
print_info() {
    echo -e "${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# 显示帮助
show_help() {
    print_info "🚀 小红书MCP服务器管理脚本"
    echo "=================================="
    echo "用法: ./start-mcp.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -b, --build     先编译再启动"
    echo "  -c, --check     仅检查服务状态"
    echo "  -s, --stop      停止MCP服务"
    echo "  -r, --restart   重启MCP服务"
    echo "  -h, --help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./start-mcp.sh           # 直接启动"
    echo "  ./start-mcp.sh --build   # 编译后启动"
    echo "  ./start-mcp.sh --check   # 检查状态"
    echo "  ./start-mcp.sh --restart # 重启服务"
}

# 检查端口
check_port() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -i :18060 >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ln | grep :18060 >/dev/null 2>&1
    else
        return 1
    fi
}

# 检查MCP服务状态
check_mcp_service() {
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" http://localhost:18060/health 2>/dev/null)
        if [[ "${response: -3}" == "200" ]]; then
            return 0
        fi
    fi
    return 1
}

# 停止MCP服务
stop_mcp_service() {
    print_warning "🛑 正在停止MCP服务..."
    
    # 查找并终止进程
    if command -v pgrep >/dev/null 2>&1; then
        pids=$(pgrep -f "xiaohongshu-mcp\|go.*server")
        if [[ -n "$pids" ]]; then
            echo "$pids" | xargs kill -TERM 2>/dev/null
            sleep 2
            echo "$pids" | xargs kill -KILL 2>/dev/null
        fi
    fi
    
    if ! check_port; then
        print_success "✅ MCP服务已停止"
        return 0
    else
        print_error "⚠️  端口18060仍被占用"
        return 1
    fi
}

# 启动MCP服务
start_mcp_service() {
    local build_first=$1
    
    print_info "🚀 启动小红书MCP服务器..."
    echo "=================================="
    
    # 检查Go环境
    print_warning "📋 检查环境..."
    if ! command -v go >/dev/null 2>&1; then
        print_error "❌ Go环境未安装或不在PATH中"
        return 1
    fi
    
    go_version=$(go version)
    print_success "✅ Go环境: $go_version"
    
    # 检查项目依赖
    if [[ -f "go.mod" ]]; then
        print_success "✅ 项目依赖: go.mod 存在"
    else
        print_error "❌ 未找到go.mod文件"
        return 1
    fi
    
    # 检查端口占用
    if check_port; then
        print_warning "⚠️  端口18060已被占用，尝试停止现有服务..."
        stop_mcp_service >/dev/null
        sleep 2
    fi
    
    # 编译（如果需要）
    if [[ "$build_first" == "true" ]]; then
        print_warning "🔨 编译项目..."
        if go build -o xiaohongshu-mcp .; then
            print_success "✅ 编译成功"
        else
            print_error "❌ 编译失败"
            return 1
        fi
    fi
    
    # 启动服务
    print_warning "🎯 启动MCP服务器..."
    
    if [[ "$build_first" == "true" && -f "./xiaohongshu-mcp" ]]; then
        echo "使用编译版本启动..."
        nohup ./xiaohongshu-mcp server >/dev/null 2>&1 &
    else
        echo "使用开发模式启动..."
        nohup go run . server >/dev/null 2>&1 &
    fi
    
    # 等待服务启动
    print_warning "⏳ 等待服务启动..."
    local max_retries=10
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        sleep 2
        if check_mcp_service; then
            print_success "✅ MCP服务器启动成功！"
            print_info "📊 服务信息:"
            echo "   - 状态: 运行中"
            echo "   - 地址: http://localhost:18060"
            echo "   - 健康检查: http://localhost:18060/health"
            echo ""
            print_success "🎉 MCP工具现在可以在Trae中使用了！"
            return 0
        fi
        
        ((retry_count++))
        echo "⏳ 重试 $retry_count/$max_retries..."
    done
    
    print_error "❌ 服务启动失败，请检查日志"
    return 1
}

# 主逻辑
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--check)
        print_info "🔍 检查MCP服务状态..."
        if check_mcp_service; then
            print_success "✅ MCP服务正在运行"
            echo "   - 访问地址: http://localhost:18060"
        else
            print_error "❌ MCP服务未运行"
        fi
        exit 0
        ;;
    -s|--stop)
        stop_mcp_service
        exit 0
        ;;
    -r|--restart)
        print_info "🔄 重启MCP服务..."
        stop_mcp_service >/dev/null
        sleep 3
        if [[ "$2" == "--build" || "$2" == "-b" ]]; then
            start_mcp_service true
        else
            start_mcp_service false
        fi
        exit 0
        ;;
    -b|--build)
        start_mcp_service true
        exit 0
        ;;
    "")
        start_mcp_service false
        exit 0
        ;;
    *)
        print_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac