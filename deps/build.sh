g++ -std=c++17 -fPIC -shared \
    ./src/bonmin_bridge.cpp \
    -o ./lib/libbonmin_bridge.so \
    -I/usr/include/coin \
    -I./include \
    -DHAVE_CSTDDEF \
    -lbonmin -lipopt