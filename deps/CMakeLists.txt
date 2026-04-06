cmake_minimum_required(VERSION 3.16)
project(bonmin_bridge LANGUAGES CXX)

add_library(bonmin_bridge SHARED bonmin_bridge.cpp)
target_compile_features(bonmin_bridge PRIVATE cxx_std_17)

find_package(PkgConfig REQUIRED)
# Adapt these to your Bonmin/Ipopt install
target_include_directories(bonmin_bridge PRIVATE /usr/include/coin)
target_link_libraries(bonmin_bridge PRIVATE bonmin ipopt)