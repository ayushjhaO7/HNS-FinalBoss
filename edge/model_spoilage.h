// Auto-generated TinyML Model: model_spoilage
// Trained on data_cold_chain.csv
// Features: temp_c, humidity
// Target: target_spoilage

#ifndef TINYML_MODEL_SPOILAGE_H
#define TINYML_MODEL_SPOILAGE_H

#include <string.h>
void score_spoilage(double * input, double * output) {
    double var0[2];
    if (input[0] <= 8.00121283531189) {
        if (input[0] <= 2.0002716779708862) {
            memcpy(var0, (double[]){0.0, 1.0}, 2 * sizeof(double));
        } else {
            if (input[1] <= 75.0494270324707) {
                memcpy(var0, (double[]){1.0, 0.0}, 2 * sizeof(double));
            } else {
                memcpy(var0, (double[]){0.0, 1.0}, 2 * sizeof(double));
            }
        }
    } else {
        memcpy(var0, (double[]){0.0, 1.0}, 2 * sizeof(double));
    }
    memcpy(output, var0, 2 * sizeof(double));
}


#endif // TINYML_MODEL_SPOILAGE_H
