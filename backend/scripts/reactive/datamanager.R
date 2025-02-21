# create listener for what mode we're currently working in (bivariate, multivariate, time series...)
datamanager <- reactiveValues()

# preload pca/plsda
observe({
  if(is.null(datamanager$reload)){
    NULL # if not reloading anything, nevermind
  }else{
    if(!is.null(mSet)){
      switch(datamanager$reload,
             mz_reverse = {
               print("reverse hits...")
               if(!mSet$metshiParams$prematched){
                 print("Please perform pre-matching first to enable this feature!")
                 return(NULL)
               }else{
                 lcl$tables$hits_table <<- unique(get_prematches(who = lcl$curr_struct,
                                                                 what = "map.structure", #map.mz as alternative
                                                                 patdb = lcl$paths$patdb)[,c("query_mz", "adduct", "%iso", "dppm")])
                 
                 shown_matches$reverse <- if(nrow(lcl$tables$hits_table) > 0){
                   lcl$tables$hits_table
                 }else{
                   data.table('name' = "Didn't find anything ( •́ .̫ •̀ )")
                 }
               }
             },
             mz_forward = {
               # show pre-matched ones
               if(mSet$metshiParams$prematched){
                 
                 shown_matches$forward <- get_prematches(who = lcl$curr_mz,
                                                         what = "query_mz",
                                                         patdb = lcl$paths$patdb) 
               }
               
               subtab = if(grepl(pattern="pie", input$tab_iden_4)) "pie" else input$tab_iden_4
               switch(subtab,
                      pie = {
                        statsmanager$calculate <- "match_pie"
                        datamanager$reload <- "match_pie"
                      },
                      word_cloud = {
                        statsmanager$calculate <- "match_wordcloud"
                        datamanager$reload <- "match_wordcloud"
                      })
               # - - - -
               if(lcl$paths$patdb != ""){
                 if(file.exists(lcl$paths$patdb)){
                   scanmode <- getIonMode(lcl$curr_mz, lcl$paths$patdb)
                   lcl$vectors$calc_adducts <<- adducts[scanmode %in% Ion_mode]$Name
                   output$magicball_add_tab <- DT::renderDataTable({
                     DT::datatable(data.table(Adduct = lcl$vectors$calc_adducts),
                                   selection = list(mode = 'multiple',
                                                    selected = lcl$vectors[[paste0(scanmode, "_selected_add")]], target="row"),
                                   options = list(pageLength = 5, dom = 'tp',
                                                  columnDefs = list(list(className = 'dt-center', targets = "_all"))),
                                   rownames = F)
                   })
                 }
               }
               # print current compound in sidebar
               output$curr_mz <- renderText(lcl$curr_mz)
               
               # make miniplot for sidebar with current compound
               output$curr_plot <- plotly::renderPlotly({
                 # --- ggplot ---
                 ggplotSummary(mSet, lcl$curr_mz, shape.fac = input$shape_var, cols = lcl$aes$mycols, cf=gbl$functions$color.functions[[lcl$aes$spectrum]],
                               styles = input$ggplot_sum_style,
                               add_stats = input$ggplot_sum_stats, col.fac = input$col_var,txt.fac = input$txt_var,
                               plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                               font = lcl$aes$font)
               })
             },
             general = {
               # change interface
               if(mSet$dataSet$cls.num <= 1){
                 interface$mode <- NULL }
               else if(mSet$dataSet$cls.num == 2){
                 interface$mode <- "bivar"}
               else{
                 interface$mode <- "multivar"}
               # reload sidebar
               output$curr_name <- renderText({mSet$dataSet$cls.name})
               # reload pca, plsda, ml(make datamanager do that)
               # update select input bars with current variable and covariables defined in excel
               updateSelectInput(session, "stats_var", selected = mSet$dataSet$cls.name, choices = c("label", colnames(mSet$dataSet$covars)[which(apply(mSet$dataSet$covars, MARGIN = 2, function(col) length(unique(col)) < gbl$constants$max.cols))]))
               updateSelectInput(session, "shape_var", choices = c("label", colnames(mSet$dataSet$covars)[which(apply(mSet$dataSet$covars, MARGIN = 2, function(col) length(unique(col)) < gbl$constants$max.cols))]))
               updateSelectInput(session, "col_var", selected = mSet$dataSet$cls.name, choices = c("label", colnames(mSet$dataSet$covars)[which(apply(mSet$dataSet$covars, MARGIN = 2, function(col) length(unique(col)) < gbl$constants$max.cols))]))
               updateSelectInput(session, "txt_var", selected = "sample", choices = c("label", colnames(mSet$dataSet$covars)[which(apply(mSet$dataSet$covars, MARGIN = 2, function(col) length(unique(col)) < gbl$constants$max.cols))]))
               updateSelectInput(session, "subset_var", choices = c("label", colnames(mSet$dataSet$covars)[which(apply(mSet$dataSet$covars, MARGIN = 2, function(col) length(unique(col)) < gbl$constants$max.cols))]))
               output$curr_name <- renderText({mSet$dataSet$cls.name})
               # if _T in sample names, data is time series. This makes the time series swap button visible.
               if(all(grepl(pattern = "_T\\d", x = rownames(mSet$dataSet$norm)))){
                 timebutton$status <- "on"
               }else{
                 timebutton$status <- "off"
               }

               if(interface$mode == 'bivar'){
                 if("tt" %in% names(mSet$analSet)){
                   if("V" %in% colnames(mSet$analSet$tt$sig.mat)){
                     updateCheckboxInput(session, "tt_nonpar", value = T)
                   }else{
                     updateCheckboxInput(session, "tt_nonpar", value = F)
                   }
                 }else{
                   updateCheckboxInput(session, "tt_nonpar", value = F)
                 }
               }

               # show a button with t-test or fold-change analysis if data is bivariate. hide otherwise.
               # TODO: add button for anova/other type of sorting...
               if(mSet$dataSet$cls.num == 2 ){
                 heatbutton$status <- "ttfc"
               }else{
                 heatbutton$status <- NULL
               }
               # tab loading
               if(mSet$dataSet$cls.num <= 1){
                 interface$mode <- NULL }
               else if(mSet$dataSet$cls.num == 2){
                 interface$mode <- "bivar"}
               else{
                 interface$mode <- "multivar"}

             },
             venn = {
               if("storage" %in% names(mSet)){
                 # save previous mset
                 mset_name = mSet$dataSet$cls.name
                 # TODO: use this in venn diagram creation
                 mSet$storage[[mset_name]] <<- list(analysis = mSet$analSet)
                 # - - - - -
                 analyses = names(mSet$storage)
                 venn_no$start <- rbindlist(lapply(analyses, function(name){
                   analysis = mSet$storage[[name]]$analysis
                   analysis_names = names(analysis)
                   # - - -
                   with.subgroups <- intersect(analysis_names, c("ml", "plsr", "pca"))
                   if(length(with.subgroups) > 0){
                     extra_names <- lapply(with.subgroups, function(anal){
                       switch(anal,
                              ml = {
                                which.mls <- setdiff(names(analysis$ml),"last")
                                ml.names = sapply(which.mls, function(meth){
                                  if(length(analysis$ml[[meth]]) > 0){
                                    paste0(meth, " - ", names(analysis$ml[[meth]]))
                                  }
                                })
                                unlist(ml.names)
                              },
                              plsr = {
                                c ("plsda - PC1", "plsda - PC2", "plsda - PC3")
                              },
                              pca = {
                                c ("pca - PC1", "pca - PC2", "pca - PC3")
                              })
                     })
                     analysis_names <- c(setdiff(analysis_names, c("ml", "plsr", "plsda", "pca")), unlist(extra_names))
                   }
                   # - - -
                   data.frame(
                     paste0(analysis_names, " (", name, ")")
                   )
                 }))
                 venn_no$now <- venn_no$start
               }else{
                 venn_no$start <- data.frame(names(mSet$analSet))
                 venn_no$now <- venn_no$start
               }
             },
             aov = {
               if(!is.null(input$timecourse_trigger)){
                 present = switch(input$timecourse_trigger,
                                  {"aov2" %in% names(mSet$analSet)},
                                  {"aov" %in% names(mSet$analSet)})
                 if(present){
                   if(input$timecourse_trigger){ # send time series anova to normal anova storage
                     which.anova <- "aov2"
                     keep <- grepl("adj\\.p", colnames(mSet$analSet$aov2$sig.mat))
                   }else{
                     which.anova = "aov"
                     keep <- c("p.value", "FDR", "Fisher's LSD")
                   }
                 }
               }else{
                 present = "aov" %in% names(mSet$analSet)
                 if(present){
                   which.anova = "aov"
                   keep <- c("p.value", "FDR", "Fisher's LSD")
                 }
               }

               if(present){
                 # render results table for UI
                 output$aov_tab <- DT::renderDataTable({
                   DT::datatable(if(is.null(mSet$analSet[[which.anova]]$sig.mat)){
                     data.table("No significant hits found")
                   }else{mSet$analSet[[which.anova]]$sig.mat[,keep]
                   },
                   selection = 'single',
                   autoHideNavigation = T,
                   options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })

                 # render manhattan-like plot for UI
                 output$aov_overview_plot <- plotly::renderPlotly({
                   # --- ggplot ---
                   ggPlotAOV(mSet,
                             cf = gbl$functions$color.functions[[lcl$aes$spectrum]], 20,
                             plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                             plotlyfy=TRUE,font = lcl$aes$font)
                 })
               }
             },
             volc = {
               # render volcano plot with user defined colours
               output$volc_plot <- plotly::renderPlotly({
                 # --- ggplot ---
                 ggPlotVolc(mSet,
                            cf = gbl$functions$color.functions[[lcl$aes$spectrum]],
                            20,
                            plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                            plotlyfy=TRUE,font = lcl$aes$font)
               })
               # render results table
               output$volc_tab <-DT::renderDataTable({
                 # -------------
                 DT::datatable(mSet$analSet$volc$sig.mat,
                               selection = 'single',
                               autoHideNavigation = T,
                               options = list(lengthMenu = c(5, 10, 15), pageLength = 5))

               })
             },
             pca = {
               if("pca" %in% names(mSet$analSet)){
                 # create PCA legend plot
                 # TODO: re-enable this plot, it was clickable so you could filter out certain groups
                 # output$pca_legend <- plotly::renderPlotly({
                 #   frame <- data.table(x = c(1),
                 #                       y = mSet$dataSet$cls.num)
                 #   p <- ggplot(data=frame,
                 #               aes(x,
                 #                   y,
                 #                   color=factor(y),
                 #                   fill=factor(y)
                 #               )
                 #   ) +
                 #     geom_point(shape = 21, size = 5, stroke = 5) +
                 #     scale_colour_manual(values=lcl$aes$$mycols) +
                 #     theme_void() +
                 #     theme(legend.position="none")
                 #   # --- return ---
                 #   ggplotly(p, tooltip = NULL) %>% config(displayModeBar = F)
                 # })
                 # render PCA variance per PC table for UI
                 output$pca_tab <-DT::renderDataTable({
                   pca.table <- as.data.table(round(mSet$analSet$pca$variance * 100.00,
                                                    digits = 2),
                                              keep.rownames = T)
                   colnames(pca.table) <- c("Principal Component", "% variance")

                   DT::datatable(pca.table,
                                 selection = 'single',
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })
                 # render PCA loadings tab for UI
                 output$pca_load_tab <-DT::renderDataTable({
                   pca.loadings <- mSet$analSet$pca$rotation[,c(input$pca_x,
                                                                input$pca_y,
                                                                input$pca_z)]
                   #colnames(pca.loadings)[1] <- "m/z"
                   DT::datatable(pca.loadings,
                                 selection = 'single',
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 10))
                 })
                 output$pca_scree <- renderPlot({
                   ggPlotScree(mSet,
                               cf = gbl$functions$color.functions[[lcl$aes$spectrum]],
                               plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                               font = lcl$aes$font)
                 })
                 # chekc which mode we're in
                 mode <- if("timecourse_trigger" %in% names(req(input))){
                   if(input$timecourse_trigger){ # if time series mode
                     "ipca" # interactive PCA (old name, i like tpca more :P )
                   }else{
                     "pca" # normal pca
                   }
                 }else{
                   "pca"
                 }

                 if(input$pca_2d3d){ # check if switch button is in 2d or 3d mode
                   # render 2d plot
                   output$plot_pca <- plotly::renderPlotly({
                     plotPCA.2d(mSet, lcl$aes$mycols,
                                pcx = input$pca_x,
                                pcy = input$pca_y, mode = mode,
                                shape.fac = input$second_var,
                                plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                                plotlyfy=TRUE,
                                font = lcl$aes$font
                               )
                   })
                 }else{
                   # render 3d plot
                   output$plot_pca <- plotly::renderPlotly({
                     plotPCA.3d(mSet, lcl$aes$mycols,
                                pcx = input$pca_x,
                                pcy = input$pca_y,
                                pcz = input$pca_z, mode = mode,
                                shape.fac = input$second_var,
                                font = lcl$aes$font)
                   })
                 }
               }else{
                 NULL
               } # do nothing
             },
             plsda = {

               if("plsda" %in% names(mSet$analSet)){ # if plsda has been performed...

                 # render cross validation plot
                 output$plsda_cv_plot <- renderPlot({
                   ggPlotClass(mSet, cf = gbl$functions$color.functions[[lcl$aes$spectrum]], plotlyfy = F,
                               plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                               font = lcl$aes$font)
                 })
                 # render permutation plot
                 output$plsda_perm_plot <- renderPlot({
                   ggPlotPerm(mSet,cf = gbl$functions$color.functions[[lcl$aes$spectrum]], plotlyfy = F,
                              plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                              font = lcl$aes$font)
                 })
                 # render table with variance per PC
                 output$plsda_tab <- DT::renderDataTable({
                   # - - - -
                   plsda.table <- as.data.table(round(mSet$analSet$plsr$Xvar
                                                      / mSet$analSet$plsr$Xtotvar
                                                      * 100.0,
                                                      digits = 2),
                                                keep.rownames = T)
                   colnames(plsda.table) <- c("Principal Component", "% variance")
                   plsda.table[, "Principal Component"] <- paste0("PC", 1:nrow(plsda.table))
                   # -------------
                   DT::datatable(plsda.table,
                                 selection = 'single',
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })
                 # render table with PLS-DA loadings
                 output$plsda_load_tab <-DT::renderDataTable({
                   plsda.loadings <- mSet$analSet$plsda$vip.mat
                   colnames(plsda.loadings) <- paste0("PC", c(1:ncol(plsda.loadings)))
                   # -------------
                   DT::datatable(plsda.loadings[, c(input$plsda_x, input$plsda_y, input$plsda_z)],
                                 selection = 'single',
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })
                 # see PCA - render 2d or 3d plots, just with plsda as mode instead
                 if(input$plsda_2d3d){
                   # 2d
                   output$plot_plsda <- plotly::renderPlotly({
                     plotPCA.2d(mSet, lcl$aes$mycols,
                                pcx = input$plsda_x,
                                pcy = input$plsda_y, mode = "plsda",
                                shape.fac = input$second_var,
                                plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                                font = lcl$aes$font)
                   })
                 }else{
                   # 3d
                   output$plot_plsda <- plotly::renderPlotly({
                     plotPCA.3d(mSet, lcl$aes$mycols,
                                pcx = input$plsda_x,
                                pcy = input$plsda_y,
                                pcz = input$plsda_z, mode = "plsda",
                                shape.fac = input$second_var,
                                font = lcl$aes$font)
                   })
                 }
               }else{NULL}
             },
             ml = {
               if("ml" %in% names(mSet$analSet)){

                 roc_data = mSet$analSet$ml[[mSet$analSet$ml$last$method]][[mSet$analSet$ml$last$name]]$roc

                 output$ml_roc <- plotly::renderPlotly({
                   plotly::ggplotly(ggPlotROC(roc_data,
                                              input$ml_attempts,
                                              gbl$functions$color.functions[[lcl$aes$spectrum]],
                                              plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                                              plotlyfy=TRUE,font = lcl$aes$font))
                 })

                 bar_data = mSet$analSet$ml[[mSet$analSet$ml$last$method]][[mSet$analSet$ml$last$name]]$bar

                 barplot_data <- ggPlotBar(bar_data,
                                         input$ml_attempts,
                                         gbl$functions$color.functions[[lcl$aes$spectrum]],
                                         input$ml_top_x,
                                         ml_name = mSet$analSet$ml$last$name,
                                         ml_type = mSet$analSet$ml$last$method,
                                         plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                                         plotlyfy=TRUE,font = lcl$aes$font)
                 
                 
                 ml_barplot <- barplot_data$plot
                 lcl$tables$ml_bar <<- barplot_data$mzdata
                 
                 output$ml_bar <- plotly::renderPlotly({

                   plotly::ggplotly(ml_barplot)
                   
                 })
                 
                 choices = c()
                 methods <- setdiff(names(mSet$analSet$ml), "last")
                 for(method in methods){
                   model.names = names(mSet$analSet$ml[[method]])
                   choices <- c(choices, paste0(method, " - ", paste0(model.names)))
                 }
                 updateSelectInput(session, "show_which_ml", choices = choices, selected = paste0(mSet$analSet$ml$last$method, " - ", mSet$analSet$ml$last$name))
                 
               }else{NULL}
             },
             asca = {
               if("asca" %in% names(mSet$analSet)){
                 output$asca_tab <-DT::renderDataTable({ # render results table for UI
                   # -------------
                   DT::datatable(mSet$analSet$asca$sig.list$Model.ab,
                                 selection = 'single',
                                 colnames = c("Compound", "Leverage", "SPE"),
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })
               }
             },
             meba = {
               if("MB" %in% names(mSet$analSet)){
                 output$meba_tab <-DT::renderDataTable({
                   # -------------
                   DT::datatable(mSet$analSet$MB$stats,
                                 selection = 'single',
                                 colnames = c("Compound", "Hotelling/T2 score"),
                                 autoHideNavigation = T,
                                 options = list(lengthMenu = c(5, 10, 15), pageLength = 5))
                 })
               }
             },
             tt = {
               # save results to table
               res <<- mSet$analSet$tt$sig.mat

               if(is.null(res)){
                 res <<- data.table("No significant hits found")
                 mSet$analSet$tt <<- NULL

               }
               # set buttons to proper thingy
               # render results table for UI
               output$tt_tab <-DT::renderDataTable({
                 # -------------
                 DT::datatable(res,
                               selection = 'single',
                               autoHideNavigation = T,
                               options = list(lengthMenu = c(5, 10, 15), pageLength = 5))

               })
               # render manhattan-like plot for UI
               output$tt_overview_plot <- plotly::renderPlotly({
                 # --- ggplot ---
                 ggPlotTT(mSet,
                          gbl$functions$color.functions[[lcl$aes$spectrum]], 20,
                          plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                          plotlyfy=TRUE,font = lcl$aes$font)
               })
             },
             fc = {
               # save results table
               res <<- mSet$analSet$fc$sig.mat
               # if none found, give the below table...
               if(is.null(res)) res <<- data.table("No significant hits found")
               # render result table for UI
               output$fc_tab <-DT::renderDataTable({
                 # -------------
                 DT::datatable(res,
                               selection = 'single',
                               autoHideNavigation = T,
                               options = list(lengthMenu = c(5, 10, 15), pageLength = 5))

               })
               # render manhattan-like plot for UI
               output$fc_overview_plot <- plotly::renderPlotly({
                 # --- ggplot ---
                 ggPlotFC(mSet,
                          gbl$functions$color.functions[[lcl$aes$spectrum]], 20,
                          plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                          plotlyfy=TRUE,font = lcl$aes$font)
               })
             },
             heatmap = {

               breaks = seq(min(mSet$dataSet$norm), max(mSet$dataSet$norm), length = 256/2)

               output$heatmap <- plotly::renderPlotly({

                 if(!is.null(mSet$analSet$heatmap$matrix)){
                   # create heatmap object
                   hmap <- suppressWarnings({
                     if(input$heatlimits){
                       heatmaply::heatmaply(mSet$analSet$heatmap$matrix[1:if(input$heatmap_topn < nrow(mSet$analSet$heatmap$matrix)) input$heatmap_topn else nrow(mSet$analSet$heatmap$matrix),],
                                            Colv = mSet$analSet$heatmap$my_order,
                                            Rowv = T,
                                            branches_lwd = 0.3,
                                            margins = c(60, 0, NA, 50),
                                            col = gbl$functions$color.functions[[lcl$aes$spectrum]],
                                            col_side_colors = mSet$analSet$heatmap$translator[,!1],
                                            col_side_palette = mSet$analSet$heatmap$colors,
                                            subplot_widths = c(.9,.1),
                                            subplot_heights = if(mSet$analSet$heatmap$my_order) c(.1, .05, .85) else c(.05,.95),
                                            column_text_angle = 90,
                                            xlab = "Sample",
                                            ylab = "m/z",
                                            showticklabels = c(T,F),
                                            limits = c(min(mSet$dataSet$norm), max(mSet$dataSet$norm)),
                                            #symm=F,symkey=F,
                                            symbreaks=T
                                            #label_names = c("m/z", "sample", "intensity") #breaks side colours...
                       )
                     }else{
                       heatmaply::heatmaply(mSet$analSet$heatmap$matrix[1:if(input$heatmap_topn < nrow(mSet$analSet$heatmap$matrix)) input$heatmap_topn else nrow(mSet$analSet$heatmap$matrix),],
                                            Colv = mSet$analSet$heatmap$my_order,
                                            Rowv = T,
                                            branches_lwd = 0.3,
                                            margins = c(60, 0, NA, 50),
                                            colors = gbl$functions$color.functions[[lcl$aes$spectrum]](256),
                                            col_side_colors = mSet$analSet$heatmap$translator[,!1],
                                            col_side_palette = mSet$analSet$heatmap$colors,
                                            subplot_widths = c(.9,.1),
                                            subplot_heights = if(mSet$analSet$heatmap$my_order) c(.1, .05, .85) else c(.05,.95),
                                            column_text_angle = 90,
                                            xlab = "Sample",
                                            ylab = "m/z",
                                            showticklabels = c(T,F),
                                            #symm=F,symkey=F,
                                            symbreaks=T
                                            #label_names = c("m/z", "sample", "intensity") #breaks side colours...
                       )
                     }
                   })
                   # save the order of mzs for later clicking functionality
                   lcl$vectors$heatmap <<- hmap$x$layout[[if(mSet$timeseries) "yaxis2" else "yaxis3"]]$ticktext 
                    # return
                   hmap
                 }else{
                   data = data.frame(text = "No significant hits available!\nPlease try alternative source statistics below.")
                   p <- ggplot(data) + geom_text(aes(label = text), x = 0.5, y = 0.5, size = 10) +
                     theme(text = element_text(family = lcl$aes$font$family)) + theme_bw()
                   plotly::ggplotly(p)
                 }
               })
             }, 
             match_wordcloud = {
               if(nrow(shown_matches$forward) > 0){
               wcdata <- data.frame(word = head(lcl$tables$word_freq, input$wc_topn)$name,
                                    freq = head(lcl$tables$word_freq, input$wc_topn)$value)
               
               output$wordcloud_desc <- wordcloud2::renderWordcloud2({
                 wordcloud2::wordcloud2(wcdata,
                                        size = 0.7,
                                        shuffle = FALSE,
                                        fontFamily = getOptions(lcl$paths$opt.loc)$font4,
                                        ellipticity = 1,
                                        minRotation = -pi/8,
                                        maxRotation = pi/8,
                                        shape = 'heart')
               })
               output$wordbar_desc <- renderPlotly({ggPlotWordBar(wcdata = wcdata,
                                                                  cf = gbl$functions$color.functions[[lcl$aes$spectrum]],
                                                                  plot.theme = gbl$functions$plot.themes[[lcl$aes$theme]],
                                                                  plotlyfy = TRUE, 
                                                                  font = lcl$aes$font)})
             }},
             match_pie = {
              
               if(nrow(shown_matches$forward) > 0){
                 
                piecharts = c("add", "db", "iso")
                
                lapply(piecharts, function(which_pie){
                  output[[paste0("match_pie_", which_pie)]] <- plotly::renderPlotly({
                    plot_ly(lcl$vectors[[paste0("pie_",which_pie)]], labels = ~Var1, 
                            values = ~value, size=~value*10, type = 'pie',
                            textposition = 'inside',
                            textinfo = 'label+percent',
                            insidetextfont = list(color = '#FFFFFF'),
                            hoverinfo = 'text',
                            text = ~paste0(Var1, ": ", value, ' matches'),
                            marker = list(colors = colors,
                                          line = list(color = '#FFFFFF', width = 1)),
                            #The 'pull' attribute can also be used to create space between the sectors
                            showlegend = FALSE) %>%
                      layout(xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
                             yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE))
                  })
                })
             }}
             )
    }

    # - - - -
    datamanager$reload <- NULL # set reloading to 'off'
  }
})
