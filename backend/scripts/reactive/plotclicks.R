# triggers when a plotly plot is clicked by user
observeEvent(plotly::event_data("plotly_click"),{

  d <- plotly::event_data("plotly_click") # get click details (which point, additional included info, etc..)
  
  for(pietype in c("add", "iso", "db")){
    if(input$tab_iden_4 == paste0("pie_",pietype)){
      i = d$pointNumber + 1
      showsubset = as.character(lcl$vectors[[paste0("pie_",pietype)]]$Var1[i])
      print(showsubset)
      if(unique(lcl$tables$last_matches$query_mz) == lcl$curr_mz){
        keep.rows <- which(lcl$tables$last_matches[[switch(pietype, 
                                                           adduct = "add", 
                                                           iso = "isocat", 
                                                           db = "source")]] == showsubset)
        shown_matches$forward <<- lcl$tables$last_matches[keep.rows,]
      }else if(mSet$metshiParams$prematched){
        shown_matches$forward <<- get_prematches(who = lcl$curr_mz,
                                                 what = "query_mz",
                                                 patdb = lcl$paths$patdb,
                                                 showadd = if(pietype=="add") showsubset else NULL,
                                                 showdb = if(pietype=="db") showsubset else NULL,
                                                 showiso = if(pietype=="iso") showsubset else NULL)
        }else{
          print("shouldnt happen lmao")
          }
      statsmanager$calculate <<- "match_pie"
      datamanager$reload <<- "match_pie"
    }
  }

  curr_tab <- switch(input$statistics,
                     dimred = {
                       input$dimred
                     }, permz = {
                       input$permz
                     }, overview = {
                       input$overview
                     }, ml = "ml")

  if(req(curr_tab ) %in% c("tt", "fc", "rf", "aov", "volc")){ # these cases need the same processing and use similar scoring systems
    if('key' %not in% colnames(d)) return(NULL)
    mzs <- switch(curr_tab,
                  tt = names(mSet$analSet$tt$p.value),
                  fc = names(mSet$analSet$fc$fc.log),
                  aov = if(mSet$timeseries)rownames(mSet$analSet$aov2$sig.mat) else names(mSet$analSet$aov$p.value),
                  volc = rownames(mSet$analSet$volcano$sig.mat)
    )
    if(d$key %not in% mzs) return(NULL)
    lcl$curr_mz <<- d$key
    
    # - magicball - 
    if(lcl$paths$patdb != "" ){
      if(file.exists(lcl$paths$patdb)){
        conn <- RSQLite::dbConnect(RSQLite::SQLite(), lcl$paths$patdb)
        scanmode <- DBI::dbGetQuery(conn, paste0("SELECT DISTINCT foundinmode FROM mzvals WHERE mzmed LIKE '", lcl$curr_mz, "%'"))[,1]
        DBI::dbDisconnect(conn)
        lcl$vectors$calc_adducts <<- adducts[scanmode %in% Ion_mode]$Name
        output$magicball_add_tab <- DT::renderDataTable({
          DT::datatable(data.table(Adduct = lcl$vectors$calc_adducts),
                        selection = list(mode = 'multiple',
                                         selected = lcl$vectors[[paste0(scanmode, "_selected_add")]], target="row"),
                        options = list(pageLength = 5, dom = 'tp'),
                        rownames = F)
        })
      }
    }
    # - return -
    output[[paste0(curr_tab, "_specific_plot")]] <- plotly::renderPlotly({
      # --- ggplot ---
      ggplotSummary(mSet, lcl$curr_mz, shape.fac = input$shape_var, cols = lcl$aes$mycols,cf=gbl$functions$color.functions[[lcl$aes$spectrum]],
                    styles = input$ggplot_sum_style, add_stats = input$ggplot_sum_stats,
                    col.fac = input$col_var, txt.fac = input$txt_var,
                    plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                    font = lcl$aes$font)
    })
  }else if(req(curr_tab) == "ml"){ # makes ROC curves and boxplots clickable
      switch(input$ml_results, roc = { # if roc, check the curve numbers of the roc plot
        attempt = d$curveNumber - 1
        xvals <- mSet$analSet$ml[[mSet$analSet$ml$last$method]][[mSet$analSet$ml$last$name]]$roc
        if(attempt > 1){
          #ml_type <- xvals$type[[1]]
          #model <- xvals$models[[attempt]]
          output$ml_tab <- DT::renderDataTable({
            imp <- as.data.table(xvals$imp[[attempt]], keep.rownames = T)
            colnames(imp) <- c("mz", "importance")
            imp <- imp[importance > 0,]
            lcl$tables$ml_roc <<- data.frame(importance = imp$importance,
                                                row.names = gsub(imp$mz,
                                                                 pattern = "`|`",
                                                                 replacement=""))
            DT::datatable(lcl$tables$ml_roc,
                          selection = 'single',
                          autoHideNavigation = T,
                          options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
          })
        }
      }, bar = { # for bar plot just grab the # bar clicked
        lcl$curr_mz <<- as.character(lcl$tables$ml_bar[d$x,"mz"][[1]])
      })}else if(req(curr_tab) == "heatmap"){#grepl(pattern = "heatmap", x = curr_tab)){ # heatmap requires the table used to make it saved to global (hmap_mzs)
        if(d$y > length(lcl$vectors$heatmap)) return(NULL)
        lcl$curr_mz <<- lcl$vectors$heatmap[d$y]
      }
  datamanager$reload <- "mz_forward"
})
