// Auto-generated TinyML Model: model_shock
// Trained on data_truck_shock.csv
// Features: accel_x, accel_y, accel_z
// Target: target_shock

#ifndef TINYML_MODEL_SHOCK_H
#define TINYML_MODEL_SHOCK_H

#include <string.h>
void score_shock(double * input, double * output) {
    double var0[2];
    if (input[2] <= 16.13599729537964) {
        if (input[2] <= 2.6046788692474365) {
            if (input[0] <= 17.2159423828125) {
                memcpy(var0, (double[]){0.2857142857142857, 0.7142857142857143}, 2 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.0, 1.0}, 2 * sizeof(double));
            }
        } else {
            memcpy(var0, (double[]){1.0, 0.0}, 2 * sizeof(double));
        }
    } else {
        memcpy(var0, (double[]){0.0, 1.0}, 2 * sizeof(double));
    }
    memcpy(output, var0, 2 * sizeof(double));
}


#endif // TINYML_MODEL_SHOCK_H
