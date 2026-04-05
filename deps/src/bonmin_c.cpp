#include "bonmin_c.h"
#include "bonmin_model.hpp"

extern "C" {

BonminModel* bonmin_create() {
    return new BonminModel();
}

void bonmin_free(BonminModel* model) {
    delete model;
}

void bonmin_add_variable(BonminModel* model,
                         double lb,
                         double ub,
                         int is_integer) {

    model->lb.push_back(lb);
    model->ub.push_back(ub);
    model->is_integer.push_back(is_integer);
    model->n_vars++;
}

double eval_objective(const std::vector<double>& x) {
    return x[0]*x[0];  // dummy
}

void bonmin_solve(BonminModel* model) {
    // later:
    // build TMINLP
    // call Bonmin
}

}