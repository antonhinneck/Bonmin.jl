g++ -fPIC -shared \
    -Iinclude \
    -I/usr/include/coin \
    -DHAVE_CSTDDEF \
    src/bonmin_c.cpp \
    -o lib/libbonmin_wrapper.so \
    -L/usr/lib/x86_64-linux-gnu \
    -lbonmin -lipopt -lCoinUtils