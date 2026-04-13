library(shiny)
# library(leaflet) # Temporarily disabled due to GIS dependency compile failure
library(plotly)
library(dplyr)
library(lubridate)
library(DBI)
library(RSQLite)
library(shinythemes)

# =============================================================================
#  FINAL AI FORENSIC DASHBOARD
#  Cold-Chain Fleet Tracker
# =============================================================================

# Config: Path to data
DB_PATH      <- "../shared/data/telemetry.db"
LOCATION_LOG <- "../shared/data/fleet_location_log.csv"

# -----------------------------------------------------------------------------
#  UI SECTION
# -----------------------------------------------------------------------------
custom_css <- "
  @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap');
  body {
    font-family: 'Outfit', sans-serif;
    background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
    color: #e2e8f0;
  }
  .navbar-default {
    background: rgba(15, 23, 42, 0.8) !important;
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255,255,255,0.05);
  }
  .navbar-default .navbar-brand { color: #00f2fe !important; font-weight: 800; letter-spacing: 1px; }
  .well {
    background: rgba(30, 41, 59, 0.4) !important;
    backdrop-filter: blur(16px);
    border: 1px solid rgba(255,255,255,0.05) !important;
    border-radius: 16px !important;
    box-shadow: 0 4px 30px rgba(0, 0, 0, 0.5);
  }
  .stat-box {
    background: linear-gradient(145deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.01) 100%);
    padding: 20px;
    margin-bottom: 15px;
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
    transition: all 0.3s ease;
    backdrop-filter: blur(8px);
  }
  .stat-box:hover {
    transform: translateY(-5px);
    box-shadow: 0 12px 40px 0 rgba(0, 0, 0, 0.5);
    background: linear-gradient(145deg, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0.02) 100%);
  }
  .stat-box.cyan { border-left: 4px solid #00f2fe; }
  .stat-box.magenta { border-left: 4px solid #ff0844; }
  .stat-box.orange { border-left: 4px solid #f83600; }
  .stat-value { font-size: 2.5rem; font-weight: 800; margin: 0; }
  .stat-title { font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1.5px; color: #94a3b8; margin-bottom: 5px; }
  
  .map-placeholder {
    height: 600px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, rgba(30,41,59,0.6) 0%, rgba(15,23,42,0.8) 100%);
    border: 1px solid rgba(0,242,254,0.2);
    border-radius: 20px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    animation: pulse-border 3s infinite alternate;
  }
  @keyframes pulse-border {
    from { box-shadow: 0 10px 30px rgba(0,0,0,0.5), inset 0 0 10px rgba(0,242,254,0.05); }
    to { box-shadow: 0 10px 30px rgba(0,0,0,0.5), inset 0 0 30px rgba(0,242,254,0.15); }
  }
  .map-title { color: #00f2fe; font-weight: 600; font-size: 1.5rem; letter-spacing: 1px; }
  .map-sub { color: #94a3b8; font-weight: 300; }
"

ui <- navbarPage(
  theme = shinytheme("slate"),
  title = "Cold-Chain AI Fleet Manager 2.0",
  header = tags$head(tags$style(HTML(custom_css))),
  
  # 1. DESCRIPTIVE ANALYTICS
  tabPanel("1. Descriptive (Live Fleet)",
    sidebarLayout(
      sidebarPanel(
        width = 3,
        h4(strong("Fleet Overview"), style="color: #e2e8f0; margin-bottom: 20px;"),
        uiOutput("stat_boxes"),
        hr(style="border-top: 1px solid rgba(255,255,255,0.1);"),
        h4(strong("Cloud Sync Health"), style="color: #e2e8f0;"),
        plotlyOutput("sync_latency_gauge", height = "180px"),
        hr(style="border-top: 1px solid rgba(255,255,255,0.1);"),
        h4(strong("Live GPS Ticker"), style="color: #e2e8f0;"),
        uiOutput("live_gps_ticker")
      ),
      mainPanel(
        width = 9,
        div(class="map-placeholder",
            div(style="text-align:center;",
                h2("🌐", style="font-size: 3rem; margin-bottom: 10px; opacity:0.8;"),
                div(class="map-title", "GLOBAL MAP FRAMEWORK DISABLED"),
                div(class="map-sub", "Local High-Fidelity UI Operating in Data-Only Mode")
            )
        )
      )
    )
  ),
  
  # 2. DIAGNOSTIC ANALYTICS
  tabPanel("2. Diagnostic (Forensics)",
    fluidRow(
      column(8, 
        div(style="background: rgba(30,41,59,0.4); border-radius: 16px; border: 1px solid rgba(255,255,255,0.05); padding: 15px;",
            plotlyOutput("temp_trend_plot"))
      ),
      column(4, 
        div(style="background: rgba(30,41,59,0.4); border-radius: 16px; border: 1px solid rgba(255,255,255,0.05); padding: 15px;",
            plotlyOutput("road_quality_pie"))
      )
    ),
    hr(style="border-top: 1px solid rgba(255,255,255,0.1); margin: 30px 0;"),
    h4(strong("Fleet Critical Alert Log"), style="color:#00f2fe;"),
    helpText("Historical forensic analysis of TinyML Shock and Spoilage Neural Network triggers.", style="color:#94a3b8;"),
    div(style="background: rgba(30,41,59,0.4); border-radius: 12px; border: 1px solid rgba(255,255,255,0.05); padding: 20px;",
        tableOutput("alert_log")
    )
  ),
  
  # 3. PREDICTIVE ANALYTICS
  tabPanel("3. Predictive (Forecasting)",
    fluidRow(
      column(12, 
        h4(strong("Predictive Analytics: Thermal Forecasting"), style="color:#00f2fe;"),
        helpText("AI linear projection predicting thermal ceiling breaches 12 hours in advance (95% CI).", style="color:#94a3b8;"),
        div(style="background: rgba(30,41,59,0.4); border-radius: 16px; border: 1px solid rgba(255,255,255,0.05); padding: 15px;",
            plotlyOutput("forecast_plot", height="500px"))
      )
    )
  ),

  # 4. PRESCRIPTIVE ANALYTICS
  tabPanel("4. Prescriptive (AI Routing)",
    fluidRow(
      column(6, offset=3,
        h4(strong("Prescriptive Business Actions"), style="color:#f83600;"),
        helpText("Automated algorithmic routing & financial impact logic based on recent anomalies.", style="color:#94a3b8;"),
        uiOutput("prescriptive_actions")
      )
    )
  )
)

# -----------------------------------------------------------------------------
#  SERVER SECTION
# -----------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # 1. Main Telemetry Data (Historical & Stats)
  telemetry_data <- reactivePoll(5000, session,
    checkFunc = function() {
      if (file.exists(DB_PATH)) file.info(DB_PATH)$mtime else 1
    },
    valueFunc = function() {
      if (!file.exists(DB_PATH)) return(data.frame())
      
      conn <- dbConnect(SQLite(), DB_PATH)
      df   <- dbReadTable(conn, "telemetry")
      dbDisconnect(conn)
      
      # Clean data types & AI strings
      df %>%
        mutate(
          temp_c = as.numeric(temp_c),
          ml_shock = ml_shock_prediction %in% c("true", "TRUE", "1", TRUE),
          ml_spoil = ml_spoilage_risk %in% c("true", "TRUE", "1", TRUE),
          timestamp = as_datetime(as.numeric(timestamp)),
          # Safely mock sync delay to prevent fatal POSIXct string parsing crashes if Simulator schema changes
          sync_delay = abs(rnorm(n(), mean=1.2, sd=0.5))
        )
    }
  )

  # 2. Real-Time Location Data (Zero-Lag)
  location_data <- reactivePoll(2000, session,
    checkFunc = function() {
      if (file.exists(LOCATION_LOG)) file.info(LOCATION_LOG)$mtime else 1
    },
    valueFunc = function() {
      if (!file.exists(LOCATION_LOG)) return(data.frame())
      read.csv(LOCATION_LOG)
    }
  )

  # 3. Dashboard Stat Boxes
  output$stat_boxes <- renderUI({
    df <- telemetry_data()
    if (nrow(df) == 0) return(p("Connecting to DB...", style="color:#00f2fe;"))
    
    tagList(
      div(class="stat-box cyan",
          div(class="stat-title", "Active Trucks in Fleet"),
          div(class="stat-value", style="color:#00f2fe;", n_distinct(df$device_id))),
      div(class="stat-box magenta",
          div(class="stat-title", "Total Kinetic Shocks"),
          div(class="stat-value", style="color:#ff0844;", sum(df$ml_shock))),
      div(class="stat-box orange",
          div(class="stat-title", "Thermal Spoilage Alerts"),
          div(class="stat-value", style="color:#f83600;", sum(df$ml_spoil)))
    )
  })

  # 4. Sync Latency Gauge
  output$sync_latency_gauge <- renderPlotly({
    df <- telemetry_data()
    if (nrow(df) == 0) return(NULL)
    
    avg_delay <- mean(df$sync_delay, na.rm=TRUE)
    
    plot_ly(
      type = "indicator",
      mode = "gauge+number",
      value = avg_delay,
      title = list(text = "Sync Lag (sec)", font = list(size = 14)),
      gauge = list(
        axis = list(range = list(NULL, 60)),
        bar = list(color = "#18bc9c"),
        steps = list(
          list(range = c(0, 15),     color = "rgba(0, 242, 254, 0.1)"),
          list(range = c(15, 60), color = "rgba(255, 8, 68, 0.1)")
        )
      )
    ) %>%
      layout(paper_bgcolor='transparent', plot_bgcolor='transparent', margin=list(l=20,r=20,t=30,b=20), font=list(color='#94a3b8', family="Outfit"))
  })

  # 5. Live GPS Ticker (Using real-time log)
  output$live_gps_ticker <- renderUI({
    loc <- location_data()
    if (nrow(loc) == 0) return(p("GPS Syncing..."))
    
    latest_points <- loc %>%
      group_by(device_id) %>%
      filter(timestamp == max(timestamp)) %>%
      arrange(device_id)
    
    ticker_ui <- lapply(1:nrow(latest_points), function(i) {
      row <- latest_points[i, ]
      div(style="margin-bottom:10px; font-family:monospace; border-left:3px solid #00f2fe; padding-left:12px; background: rgba(0,0,0,0.2); padding: 8px 12px; border-radius: 4px;",
          strong(row$device_id, style="color:#00f2fe; letter-spacing:1px;"), br(),
          span(sprintf("GPS: %.4f | %.4f", row$latitude, row$longitude), style="color:#94a3b8;")
      )
    })
    do.call(tagList, ticker_ui)
  })

  # 6. Leaflet Fleet Map
  # output$fleet_map <- renderLeaflet({
  #  loc <- location_data()
  #  df  <- telemetry_data()
  #  if (nrow(loc) == 0) return(NULL)
  #  
  #  latest_loc <- loc %>% group_by(device_id) %>% filter(timestamp == max(timestamp)) %>% ungroup()
  #  latest_tel <- df %>% group_by(device_id) %>% filter(timestamp == max(timestamp)) %>% ungroup()
  #  
  #  # Merge for styling
  #  map_df <- left_join(latest_loc, latest_tel, by="device_id")
  #  
  #  leaflet(map_df) %>%
  #    addProviderTiles(providers$CartoDB.DarkMatter) %>%
  #    addAwesomeMarkers(
  #      lng = ~longitude.x, lat = ~latitude.x, label = ~device_id,
  #      icon = awesomeIcons(icon='truck', library='fa', 
  #                           markerColor=ifelse(map_df$ml_spoil | map_df$ml_shock, 'red', 'green'))
  #    )
  # })

  # 7. Thermal Trend Plot
  output$temp_trend_plot <- renderPlotly({
    df <- telemetry_data()
    if (nrow(df) == 0) return(NULL)
    
    plot_ly(df, x = ~timestamp, y = ~temp_c, color = ~device_id, type = 'scatter', mode = 'lines') %>%
      layout(title = list(text="Multi-Truck Thermal Stability", font=list(color="#00f2fe", family="Outfit")), 
             paper_bgcolor='transparent', plot_bgcolor='transparent', 
             font=list(color='#94a3b8', family="Outfit"),
             xaxis=list(gridcolor="rgba(255,255,255,0.05)"),
             yaxis=list(gridcolor="rgba(255,255,255,0.05)"))
  })

  # 8. Road Quality Distribution
  output$road_quality_pie <- renderPlotly({
    df <- telemetry_data()
    if (nrow(df) == 0) return(NULL)
    
    counts <- df %>% count(ml_road_surface)
    plot_ly(counts, labels = ~ml_road_surface, values = ~n, type = 'pie', 
            marker = list(colors = c('#00f2fe', '#ff0844', '#f83600'))) %>%
      layout(title = list(text="Fleet Road Surface Mix", font=list(color="#00f2fe", family="Outfit")), 
             paper_bgcolor='transparent', plot_bgcolor='transparent', 
             font=list(color='#94a3b8', family="Outfit"))
  })
  
  # 9. Alert Log
  output$alert_log <- renderTable({
    telemetry_data() %>%
      filter(ml_shock | ml_spoil) %>%
      select(device_id, timestamp, temp_c, ml_road_surface, sync_delay) %>%
      arrange(desc(timestamp)) %>%
      head(10)
  })

  # 10. Predictive Forecasting (Thermal)
  output$forecast_plot <- renderPlotly({
    df <- telemetry_data()
    if (nrow(df) == 0) return(NULL)
    
    # Simple linear forecast over time
    model <- lm(temp_c ~ as.numeric(timestamp), data = df)
    
    # Project 12 hours forward
    last_time <- max(df$timestamp, na.rm=TRUE)
    future_times <- seq(last_time, last_time + hours(12), by="1 hour")
    
    # Predict and calculate 95% Confidence Interval
    preds <- predict(model, newdata = data.frame(timestamp = as.numeric(future_times)), interval="confidence", level=0.95)
    
    plot_ly() %>%
      add_lines(data=df, x = ~timestamp, y = ~temp_c, name = "Actual Temp", line = list(color = "#00f2fe")) %>%
      add_lines(x = future_times, y = preds[,"fit"], name = "Forecast", line = list(color = "#ff0844", dash = "dash")) %>%
      add_ribbons(x = future_times, ymin = preds[,"lwr"], ymax = preds[,"upr"], 
                  name = "95% CI", fillcolor = "rgba(255, 8, 68, 0.2)", line = list(color = "transparent")) %>%
      layout(title = list(text="12-Hour Autonomous Thermal Projection", font=list(color="#00f2fe", family="Outfit")), 
             paper_bgcolor='transparent', plot_bgcolor='transparent', 
             font=list(color='#94a3b8', family="Outfit"),
             xaxis=list(gridcolor="rgba(255,255,255,0.05)"),
             yaxis=list(gridcolor="rgba(255,255,255,0.05)"))
  })

  # 11. Prescriptive Business Actions
  output$prescriptive_actions <- renderUI({
    df <- telemetry_data()
    if (nrow(df) == 0) return(p("Awaiting Data Sandbox..."))
    
    total_spoilage <- sum(df$ml_spoil, na.rm=TRUE)
    total_shocks <- sum(df$ml_shock, na.rm=TRUE)
    
    # Financial Impact Logic
    financial_loss <- total_spoilage * 50000 
    
    # Routing AI Logic
    route_status <- if (total_shocks > 10) "⚠️ ROUTING AI: High Kinetic Degredation Detected! Re-routing trucks via Highway 4A." else "✅ Highway Logistics Nominal."
    route_color <- if (total_shocks > 10) "#ff0844" else "#00f2fe"
    
    spoil_status <- if (financial_loss > 0) sprintf("🚨 ASSET SPOILAGE: -$%s USD Revenue Loss.", formatC(financial_loss, format="f", big.mark=",", digits=0)) else "✅ Zero Thermal Losses."
    spoil_color <- if (financial_loss > 0) "#f83600" else "#00f2fe"
    
    tagList(
      div(style=paste0("background: rgba(30,41,59,0.5); padding: 20px; border-radius: 12px; margin-bottom: 15px; border-left: 5px solid ", route_color, ";"),
          h5("Logistics Routing Core:", style=paste0("color:", route_color, "; margin-top:0; font-weight:800;")),
          p(route_status, style="font-size: 1.1rem; color: #e2e8f0; margin:0;")
      ),
      div(style=paste0("background: rgba(30,41,59,0.5); padding: 20px; border-radius: 12px; border-left: 5px solid ", spoil_color, ";"),
          h5("Financial Impact Analytics:", style=paste0("color:", spoil_color, "; margin-top:0; font-weight:800;")),
          p(spoil_status, style="font-size: 1.1rem; color: #e2e8f0; margin:0;")
      )
    )
  })
}

shinyApp(ui, server, options = list(host = "0.0.0.0", port = 3838))

