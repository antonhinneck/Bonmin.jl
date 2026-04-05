#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// opaque handle
typedef struct BonminModel BonminModel;

// lifecycle
BonminModel* bonmin_create();
void bonmin_free(BonminModel* model);

// variables
void bonmin_add_variable(BonminModel* model,
                         double lb,
                         double ub,
                         int is_integer);

// objective
void bonmin_set_quadratic_objective(void* model);

// solve
void bonmin_solve(BonminModel* model);

#ifdef __cplusplus
}
#endif