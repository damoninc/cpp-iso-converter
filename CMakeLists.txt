cmake_minimum_required(VERSION 3.16)
project(ciso2iso LANGUAGES CXX)

add_executable(ciso2iso
    src/main.cpp
    src/ciso.cpp
)

target_include_directories(ciso2iso PRIVATE src)
target_compile_features(ciso2iso PRIVATE cxx_std_17)

if(MSVC)
    target_compile_options(ciso2iso PRIVATE /W4 /permissive-)
else()
    target_compile_options(ciso2iso PRIVATE -Wall -Wextra -Wpedantic)
endif()
