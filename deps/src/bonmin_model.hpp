#pragma once
#include <vector>
#include "BonBonminSetup.hpp"

struct BonminModel {
    int n_vars = 0;

    std::vector<double> lb, ub;
    std::vector<bool> is_integer;

    Bonmin::BonminSetup setup;
};