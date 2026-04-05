#include "bonmin_tminlp.hpp"
#include <cstdio>

// constructor
MyTMINLP::MyTMINLP(BonminModel* m) : model(m) {}


// =============================
// Problem size
// =============================
bool MyTMINLP::get_nlp_info(int& n, int& m,
                            int& nnz_jac_g, int& nnz_h_lag,
                            IndexStyleEnum& index_style) {

    n = model->n_vars;
    m = 0;                 // no constraints yet
    nnz_jac_g = 0;
    nnz_h_lag = 0;

    index_style = TNLP::C_STYLE;
    return true;
}


// =============================
// Bounds
// =============================
bool MyTMINLP::get_bounds_info(int n, double* x_l, double* x_u,
                               int m, double* g_l, double* g_u) {

    for (int i = 0; i < n; i++) {
        x_l[i] = model->lb[i];
        x_u[i] = model->ub[i];
    }

    return true;
}


// =============================
// Variable types
// =============================
bool MyTMINLP::get_variables_types(int n, VariableType* var_types) {

    for (int i = 0; i < n; i++) {
        var_types[i] = model->is_integer[i] ? INTEGER : CONTINUOUS;
    }

    return true;
}


// =============================
// Objective function
// f(x) = sum(x_i^2)
// =============================
bool MyTMINLP::eval_f(int n, const double* x, bool,
                      double& obj_value) {

    obj_value = 0.0;

    for (int i = 0; i < n; i++) {
        obj_value += x[i] * x[i];
    }

    return true;
}


// =============================
// Gradient of objective
// ∂f/∂x_i = 2x_i
// =============================
bool MyTMINLP::eval_grad_f(int n, const double* x, bool,
                           double* grad_f) {

    for (int i = 0; i < n; i++) {
        grad_f[i] = 2.0 * x[i];
    }

    return true;
}


// =============================
// Starting point
// =============================
bool MyTMINLP::get_starting_point(int n, bool init_x, double* x,
                                  bool, double*, double*,
                                  int, bool, double*) {

    if (init_x) {
        for (int i = 0; i < n; i++) {
            x[i] = 0.0;
        }
    }

    return true;
}


// =============================
// Final solution callback
// =============================
void MyTMINLP::finalize_solution(SolverReturn status,
                                 int n, const double* x,
                                 const double*, const double*,
                                 int, const double*,
                                 const double*,
                                 double obj_value,
                                 const IpoptData*,
                                 IpoptCalculatedQuantities*) {

    printf("=== Bonmin Solution ===\n");
    printf("Status: %d\n", status);

    for (int i = 0; i < n; i++) {
        printf("x[%d] = %f\n", i, x[i]);
    }

    printf("Objective = %f\n", obj_value);
}