#include "bonmin_bridge.h"

#include <vector>
#include <cstring>
#include <stdexcept>
#include <limits>

#include "BonTMINLP.hpp"
#include "BonBonminSetup.hpp"
#include "IpIpoptApplication.hpp"
#include "BonCbc.hpp"

using Ipopt::Index;
using Ipopt::Number;
using Ipopt::SmartPtr;

struct CallbackBundle {
    void* user_data;
    bonmin_eval_f_cb eval_f;
    bonmin_eval_grad_f_cb eval_grad_f;
    bonmin_eval_g_cb eval_g;
    bonmin_eval_jac_g_cb eval_jac_g;
};

class MoiTMINLP : public Bonmin::TMINLP {
public:
    MoiTMINLP(
        int n_,
        int m_,
        int m_nlp_,
        const double* x_l_,
        const double* x_u_,
        const double* x0_,
        const int* var_types_,
        const double* g_l_,
        const double* g_u_,
        const int* jac_i_,
        const int* jac_j_,
        int nnz_jac_,
        CallbackBundle cb_
    )
    : n(n_),
      m(m_),
      m_nlp(m_nlp_),
      nnz_jac(nnz_jac_),
      cb(cb_),
      x_l(x_l_, x_l_ + n_),
      x_u(x_u_, x_u_ + n_),
      x0(x0_, x0_ + n_),
      var_types(var_types_, var_types_ + n_),
      g_l(g_l_, g_l_ + m_),
      g_u(g_u_, g_u_ + m_),
      jac_i(jac_i_, jac_i_ + nnz_jac_),
      jac_j(jac_j_, jac_j_ + nnz_jac_),
      x_sol(n_, 0.0),
      obj_sol(0.0) {}

    bool get_nlp_info(Index& n_, Index& m_, Index& nnz_jac_g, Index& nnz_h_lag,
                      Ipopt::TNLP::IndexStyleEnum& index_style) override {
        n_ = n;
        m_ = m;
        nnz_jac_g = nnz_jac;
        nnz_h_lag = 0; // start without exact Hessian
        index_style = Ipopt::TNLP::C_STYLE;
        return true;
    }

    bool get_bounds_info(Index, Number* xl, Number* xu, Index, Number* gl, Number* gu) override {
        std::memcpy(xl, x_l.data(), sizeof(Number) * n);
        std::memcpy(xu, x_u.data(), sizeof(Number) * n);
        std::memcpy(gl, g_l.data(), sizeof(Number) * m);
        std::memcpy(gu, g_u.data(), sizeof(Number) * m);
        return true;
    }

    bool get_starting_point(Index, bool init_x, Number* x,
                            bool init_z, Number*, Number*,
                            Index, bool init_lambda, Number*) override {
        if (init_x) {
            std::memcpy(x, x0.data(), sizeof(Number) * n);
        }
        if (init_z || init_lambda) {
            return false;
        }
        return true;
    }

    bool get_variables_types(Index, VariableType* out) override {
        for (int i = 0; i < n; ++i) {
            out[i] = (var_types[i] == 2) ? BINARY :
                     (var_types[i] == 1) ? INTEGER :
                                           CONTINUOUS;
        }
        return true;
    }

    bool get_variables_linearity(Index n_,
                             Ipopt::TNLP::LinearityType* var_lin) override {
        for (Index i = 0; i < n_; ++i) {
            var_lin[i] = Ipopt::TNLP::NON_LINEAR;
        }
        return true;
    }

    bool get_constraints_linearity(Index m_,
                               Ipopt::TNLP::LinearityType* con_lin) override {
        for (Index i = 0; i < m_; ++i) {
            if (i < m_nlp)
                con_lin[i] = Ipopt::TNLP::NON_LINEAR;
            else
                con_lin[i] = Ipopt::TNLP::LINEAR;
        }
        return true;
    }

    bool eval_f(Index, const Number* x, bool, Number& obj_value) override {
        obj_value = cb.eval_f(cb.user_data, x, n);
        return true;
    }

    bool eval_grad_f(Index, const Number* x, bool, Number* grad_f) override {
        //std::cerr << "C++ eval_grad_f called, n = " << n << "\n";
        cb.eval_grad_f(cb.user_data, x, n, grad_f);
        return true;
    }

    bool eval_g(Index, const Number* x, bool, Index, Number* g) override {
        cb.eval_g(cb.user_data, x, n, g, m);
        return true;
    }

    bool eval_jac_g(Index, const Number* x, bool, Index, Index, Index* iRow, Index* jCol, Number* values) override {
        if (values == nullptr) {
            for (int k = 0; k < nnz_jac; ++k) {
                iRow[k] = jac_i[k];
                jCol[k] = jac_j[k];
            }
        } else {
            cb.eval_jac_g(cb.user_data, x, n, values, nnz_jac);
        }
        return true;
    }

    bool eval_h(Index, const Number*, bool, Number, Index, const Number*, bool,
                Index, Index*, Index*, Number*) override {
        return false; // use quasi-Newton / no exact Hessian for v1
    }

    void finalize_solution(Bonmin::TMINLP::SolverReturn status,
                       Index n_, const Number* x, Number obj_value) override {
        obj_sol = obj_value;

        if (status != Bonmin::TMINLP::SUCCESS || x == nullptr || n_ <= 0 || n_ != n) {
            x_sol.clear();
            return;
        }

        x_sol.assign(x, x + n_);
    }

    const Bonmin::TMINLP::SosInfo* sosConstraints() const override {
        return nullptr;
    }

    const Bonmin::TMINLP::BranchingInfo* branchingInfo() const override {
        return nullptr;
    }

    std::vector<double> x_sol;
    double obj_sol;

private:
    int n, m, m_nlp, nnz_jac;
    CallbackBundle cb;
    std::vector<double> x_l, x_u, x0, g_l, g_u;
    std::vector<int> var_types, jac_i, jac_j;
};

extern "C" double bonmin_solve_problem(
    int n,
    int m,
    int m_nlp,
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
) {
    CallbackBundle cb{user_data, eval_f, eval_grad_f, eval_g, eval_jac_g};

    SmartPtr<MoiTMINLP> tminlp = new MoiTMINLP(
        n, m, m_nlp,
        x_l, x_u, x0, var_types,
        g_l, g_u,
        jac_i, jac_j,
        nnz_jac,
        cb
    );

    Bonmin::BonminSetup setup;
    setup.initialize(tminlp);

    setup.options()->SetStringValue(
        "hessian_approximation",
        "limited-memory",
        true,
        true
    );

    Bonmin::Bab bb;
    bb(setup);

    if ((int)tminlp->x_sol.size() == n) {
        for (int i = 0; i < n; ++i) {
            x_out[i] = tminlp->x_sol[i];
        }
        return tminlp->obj_sol;
    }

    // No solution produced
    for (int i = 0; i < n; ++i) {
        x_out[i] = x0[i];
    }
    return std::numeric_limits<double>::quiet_NaN();
}