#ifndef BONMIN_BRIDGE_H
#define BONMIN_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef double (*bonmin_eval_f_cb)(void* user_data, const double* x, int n);
typedef void (*bonmin_eval_grad_f_cb)(void* user_data, const double* x, int n, double* grad);
typedef void (*bonmin_eval_g_cb)(void* user_data, const double* x, int n, double* g, int m);
typedef void (*bonmin_eval_jac_g_cb)(void* user_data, const double* x, int n, double* values, int nnz);

double bonmin_solve_problem(
    int n,
    int m,
    const double* x_l,
    const double* x_u,
    const double* x0,
    const int* var_types,
    const double* g_l,
    const double* g_u,
    const int* jac_i,
    const int* jac_j,
    int nnz_jac,
    void* user_data,
    bonmin_eval_f_cb eval_f,
    bonmin_eval_grad_f_cb eval_grad_f,
    bonmin_eval_g_cb eval_g,
    bonmin_eval_jac_g_cb eval_jac_g,
    double* x_out
);

#ifdef __cplusplus
}
#endif

#endif