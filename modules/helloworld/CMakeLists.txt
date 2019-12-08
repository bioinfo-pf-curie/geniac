cmake_minimum_required(VERSION 2.8.9)
project(helloworld LANGUAGES CXX)
project (helloworld)

add_executable(helloworld main.cpp)
install(TARGETS helloworld DESTINATION ${CMAKE_INSTALL_PREFIX})
