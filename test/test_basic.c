#include "bonmin-c.h"
#include <stdio.h>

int main() {
    void* model = bonmin_create();
    bonmin_add_variable(model, 0.0, 10.0);
    bonmin_solve(model);
    printf("OK\n");
    return 0;
}