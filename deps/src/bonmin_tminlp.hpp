#pragma once

#include "BonTMINLP.hpp"
#include "bonmin_model.hpp"

class MyTMINLP : public Bonmin::TMINLP {
public:
    BonminModel* model;

    MyTMINLP(BonminModel* m);

    // required overrides
    bool get_nlp_info(int&, int&, int&, int&, IndexStyleEnum&) override;
    bool get_bounds_info(int, double*, double*, int, double*, double*) override;
    bool get_variables_types(int, VariableType*) override;
    bool eval_f(int, const double*, bool, double&) override;
    bool eval_grad_f(int, const double*, bool, double*) override;
    bool get_starting_point(int, bool, double*, bool, double*, double*, int, bool, double*) override;
};