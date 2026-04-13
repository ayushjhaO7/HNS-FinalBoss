// Auto-generated TinyML Model: model_road
// Trained on data_road_surface.csv
// Features: accel_x, accel_y, accel_z
// Target: target_road

#ifndef TINYML_MODEL_ROAD_H
#define TINYML_MODEL_ROAD_H

#include <string.h>
void score_road(double * input, double * output) {
    double var0[3];
    if (input[0] <= -0.4770527631044388) {
        if (input[0] <= -2.7918328046798706) {
            if (input[0] <= -3.385274648666382) {
                memcpy(var0, (double[]){0.0, 0.05785123966942149, 0.9421487603305785}, 3 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.0, 0.3125, 0.6875}, 3 * sizeof(double));
            }
        } else {
            if (input[2] <= 5.347089529037476) {
                memcpy(var0, (double[]){0.0, 0.1590909090909091, 0.8409090909090909}, 3 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.01728395061728395, 0.7580246913580246, 0.22469135802469137}, 3 * sizeof(double));
            }
        }
    } else {
        if (input[0] <= 0.443628191947937) {
            if (input[1] <= 0.6234141290187836) {
                memcpy(var0, (double[]){0.8995098039215687, 0.08026960784313726, 0.02022058823529412}, 3 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.016666666666666666, 0.725, 0.25833333333333336}, 3 * sizeof(double));
            }
        } else {
            if (input[0] <= 3.5448191165924072) {
                memcpy(var0, (double[]){0.026119402985074626, 0.6585820895522388, 0.31529850746268656}, 3 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.0, 0.10638297872340426, 0.8936170212765957}, 3 * sizeof(double));
            }
        }
    }
    memcpy(output, var0, 3 * sizeof(double));
}


#endif // TINYML_MODEL_ROAD_H
