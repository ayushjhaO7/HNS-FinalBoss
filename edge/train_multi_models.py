import pandas as pd
from sklearn.tree import DecisionTreeClassifier
import m2cgen as m2c
import os

DATA_DIR = "../shared/data"

def train_and_export(csv_name, features, target_col, model_name, function_name):
    path = os.path.join(DATA_DIR, csv_name)
    print(f"Loading {path} for {model_name}...")
    df = pd.read_csv(path)
    
    X = df[features]
    y = df[target_col]
    
    print(f"Training {model_name} (Samples: {len(X)})...")
    clf = DecisionTreeClassifier(max_depth=3, random_state=42) # Limit depth for ESP32 constraints
    clf.fit(X, y)
    
    acc = clf.score(X, y)
    print(f"Training Accuracy ({model_name}): {acc * 100:.2f}%")
    
    print(f"Transpiling to C++...")
    c_code = m2c.export_to_c(clf)
    
    # By default, m2cgen generates a function named `score`. 
    # We must rename it so all 3 models can coexist in one Arduino project.
    c_code = c_code.replace("void score(", f"void {function_name}(")
    
    header_content = f"""// Auto-generated TinyML Model: {model_name}
// Trained on {csv_name}
// Features: {', '.join(features)}
// Target: {target_col}

#ifndef TINYML_{model_name.upper()}_H
#define TINYML_{model_name.upper()}_H

{c_code}

#endif // TINYML_{model_name.upper()}_H
"""
    
    with open(f"{model_name}.h", "w") as f:
        f.write(header_content)
        
    print(f"Success! Model exported to {model_name}.h\n")


if __name__ == "__main__":
    print("--- Multi-Model Training Pipeline ---")
    
    # 1. Shock Model
    train_and_export(
        csv_name="data_truck_shock.csv",
        features=['accel_x', 'accel_y', 'accel_z'],
        target_col='target_shock',
        model_name="model_shock",
        function_name="score_shock"
    )
    
    # 2. Road Surface Model
    train_and_export(
        csv_name="data_road_surface.csv",
        features=['accel_x', 'accel_y', 'accel_z'],
        target_col='target_road',
        model_name="model_road",
        function_name="score_road"
    )
    
    # 3. Spoilage Risk Model
    train_and_export(
        csv_name="data_cold_chain.csv",
        features=['temp_c', 'humidity'],
        target_col='target_spoilage',
        model_name="model_spoilage",
        function_name="score_spoilage"
    )
    
    print("--- Complete ---")
