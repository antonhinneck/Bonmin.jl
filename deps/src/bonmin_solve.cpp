#include "BonBonminSetup.hpp"
#include "BonBab.hpp"

extern "C" {

void bonmin_solve(BonminModel* model) {

    Bonmin::BonminSetup setup;

    Ipopt::SmartPtr<MyTMINLP> tminlp = new MyTMINLP(model);

    setup.initialize(tminlp);

    Bonmin::Bab bb;
    bb(setup);
}

}