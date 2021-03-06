require './app/tools/z3interface/schedule'
require 'json'

class SurgeriesController < ApplicationController
  protect_from_forgery prepend: true, with: :exception

  def show
    if(params[:commit] == "手动排白班")
      autoOrManualRun(params[:start_date], params[:end_date], false)
    else
      autoOrManualRun(params[:start_date], params[:end_date], true)
    end
  end

  def surgeriesList
    today = Time.new
    start_date = (today.year).to_s + "-" + today.month.to_s + "-01"
    if(today.month !=12)
      end_date = today.year.to_s + "-" + (today.month + 1).to_s + "-01"
    else
      end_date = (today.year+1).to_s + "-01-01"
    end
    dates = processDate(start_date, end_date)
    @surgeries = selectSurgeries(dates)
    initialClientTableJson(dates)
    initialSurgeriesJson(@surgeries)
    if(!(validateDateHasNightResult(dates)))
      flash[:day_notice] = "您还没有排当月的夜班，请先排当月的夜班再排白班"
      flash[:night_notice] = "还没有排夜班"
      render 'surgeries/list'
    else
    render 'surgeries/list'
    end
  end

  def dayScheduleShow
    today = Time.new
    start_date = (today.year).to_s + "-" + today.month.to_s + "-01"
    if(today.month !=12)
      end_date = today.year.to_s + "-" + (today.month + 1).to_s + "-01"
    else
      end_date = (today.year+1).to_s + "-01-01"
    end
    
    dates = processDate(start_date, end_date)
    @surgeries = selectSurgeries(dates)
    initialClientTableJson(dates)
    initialSurgeriesJson(@surgeries)
    dates = processDate(start_date,end_date)
    if(!(validateDateHasNightResult(dates)))
      flash[:day_notice] = "您还没有排当月的夜班，请先排当月的夜班再排白班"
      render 'surgeries/dayScheduleShow' 
    else
      render 'surgeries/dayScheduleShow'
    end 
  end

  def autoOrManualRun(startD, endD, autoOrManual)
    if(!session[:start_date].nil?)
      start_date = session[:start_date]
      end_date = session[:end_date]
    else
      start_date = startD[:year] + "-" + startD[:month] + "-" + startD[:day]
      end_date = endD[:year] + "-" + endD[:month] + "-" + endD[:day]
    end
    dates = processDate(start_date, end_date)
    if(dates.length == 0)
      flash[:date_notice] = "日期选择不合法"
      render 'schedules/show'
    elsif (!validateDateIsInOneMonth(dates))
      flash[:date_notice] = "目前不支持跨月排白班，请选择一个月内的日期进行排班"
      render 'schedules/show'
    elsif (!validateDateHasNightResult(dates))
      flash[:date_notice] = "您还没有排当月的夜班，请先排当月的夜班再排白班"
      render 'schedules/show'
    else
      session[:start_date] = start_date
      session[:end_date] = end_date
      flash[:date_notice] = nil
      modifyMonthInfoJson(processDayDate(dates))
      modifyMonthTableJson(processDayDate(dates))
      @surgeries = selectSurgeries(dates)
      initialClientTableJson(dates)
      initialSurgeriesJson(@surgeries)
      if(autoOrManual == true)
        runAlgorithm()
      else
        render 'surgeries/show'
      end
    end
  end

  def modifyMonthTableJson(dates)
    monthTable = {}

    for date in dates
      ns = NightSchedule.find_by(date: date)
      array = Array.new
      array1 = Array.new
      array2 = Array.new
      array3 = Array.new
      array1.push(ns.nurse1_id.to_s)
      array1.push(ns.nurse2_id.to_s)
      array1.push(ns.nurse3_id.to_s)
      array2.push(ns.nurse4_id.to_s)
      array2.push(ns.nurse5_id.to_s)
      array2.push(ns.nurse6_id.to_s)
      array3.push(ns.nurse7_id.to_s)
      array3.push(ns.nurse8_id.to_s)
      array3.push(ns.nurse9_id.to_s)
      array.push(array1)
      array.push(array2)
      array.push(array3)
      monthTable.store(date, array)
    end
    File.new("./db/json/monthTable.json", "w").syswrite(JSON.pretty_generate(monthTable.as_json))
  end

  def modifyMonthInfoJson(dates)
     File.new("./db/json/monthInfo.json", "w").syswrite(JSON.pretty_generate(dates.as_json))
  end

  def processDayDate(dates)
    start_date = dates[0].year.to_s + "-" + dates[0].month.to_s + "-01"
    if(dates[0].month != 12)
      end_date = dates[0].year.to_s + "-" + (dates[0].month + 1).to_s + "-01"
    else
      end_date = (dates[0].year + 1).to_s + "-01-01"
    end
    dates = processDate(start_date, end_date)
    dates.delete_at(dates.length - 1)
    return dates
  end

  def validateDateIsInOneMonth(dates)
    month = dates[0].month
    for date in dates
      if(date.month != month)
        return false
      end
    end
    return true
  end

  def validateDateHasNightResult(dates)
    for date in dates
      if(NightSchedule.find_by(date: date) == nil)
        return false
      end
    end
    return true
  end

  def selectSurgeries(dates) 
    surgeries = Array.new
    for date in dates
      s = Surgery.where(date: date)
      for surgery in s
        surgeries.push(surgery)
      end
    end
    return surgeries
  end

  def processDate(startD, endD)
    start_date = Date.parse(startD)
    end_date = Date.parse(endD)
    dates = (start_date..end_date).to_a
    return dates
  end

  def initialSurgeriesJson(surgeries)
    File.new("./db/json/surgeries.json", "w").syswrite(JSON.pretty_generate(surgeries.as_json))
  end

  def initialClientTableJson(dates)
    clientTable = {}
    nurses = Nurse.all

    array = Array.new
    for nurse in nurses
      array.push(nurse.id.to_s)
    end

    for date in dates
      s = Surgery.where(date: date)
      hash = {}
      for surgery in s
        hash.store(surgery.id, array)
      end
      clientTable.store(date, hash)
    end

    File.new("./db/json/clientTable.json", "w").syswrite(JSON.pretty_generate(clientTable.as_json))
  end

  def daySchedule
    @surgery = Surgery.find(params[:surgery_id])
  	@nurses = Nurse.all
  	render 'surgeries/schedule'
  end

  def addNurse
    if(session[:nurse].nil?)
      if(params[:nurse].length <= 1)
        @surgery = Surgery.find(params[:surgery_id])
        @nurses = Nurse.all
        flash[:nurse_notice] = "请至少选择两个护士"
        render 'surgeries/schedule'
      else
        session[:nurse] = params[:nurse]
        session[:surgery_id] = params[:surgery_id]
        surgery_id = params[:surgery_id]
        surgery_date = Surgery.find(surgery_id).date.to_s
        modifyClientTable(params[:nurse], surgery_id, surgery_date)
        @surgeries = selectSurgeries(processDate(session[:start_date], session[:end_date]))
        flash[:nurse_notice] = nil
        render 'surgeries/show'
      end
    else
      if(session[:nurse].length <= 1)
        @surgery = Surgery.find(session[:surgery_id])
        @nurses = Nurse.all
        flash[:nurse_notice] = "请至少选择两个护士"
        render 'surgeries/schedule'
      else
        surgery_id = session[:surgery_id]
        surgery_date = Surgery.find(surgery_id).date.to_s
        modifyClientTable(session[:nurse], surgery_id, surgery_date)
        @surgeries = selectSurgeries(processDate(session[:start_date], session[:end_date]))
        flash[:nurse_notice] = nil
        render 'surgeries/show'
      end
    end
  end

  def modifyClientTable(nurses_id, surgery_id, surgery_date)
    clientTable = JSON.parse(File.read("./db/json/clientTable.json"))
    if(clientTable.has_key?(surgery_date))
      if(clientTable[surgery_date].has_key?(surgery_id))
        clientTable[surgery_date][surgery_id] = nurses_id
      else
        clientTable[surgery_date].store(surgery_id, nurses_id)
      end
    else
      hash = {}
      hash.store(surgery_id, nurses_id)
      clientTable.store(surgery_date, hash)
    end
    File.new("./db/json/clientTable.json", "w").syswrite(JSON.pretty_generate(clientTable.as_json))
  end

  def runAlgorithm
    load('./app/tools/z3interface/schedule.rb')
    if(File.exist?("./z3py/generate/json/dayResult.json"))
      File.delete("./z3py/generate/json/dayResult.json")
    end
    result = daySchedulez3()
    if(!File.exist?("./z3py/generate/json/dayResult.json"))
      @surgeries = selectSurgeries(processDate(session[:start_date], session[:end_date]))
      flash[:schedule_notice] = "无可用结果，请重新选择护士进行排班"
      render 'surgeries/show'
    else
      dayScheduleResult = JSON.parse(File.read("./z3py/generate/json/dayResult.json"))
      updateSurgeries(dayScheduleResult)
      @surgeries = selectSurgeries(processDate(session[:start_date], session[:end_date]))
      flash[:schedule_notice] = "排班成功"
      render 'surgeries/show'
    end
  end

  def updateSurgeries(dayScheduleResult)
    dayScheduleResult.each_key { |date|
      dayScheduleResult[date]["day"].each_key { |surgery_id|
        surgery = Surgery.find(surgery_id.to_i)
        surgery.update(instrument_nurse_id: dayScheduleResult[date]["day"][surgery_id]["instrument"].to_i, 
          roving_nurse_id: dayScheduleResult[date]["day"][surgery_id]["roving"].to_i)
      }
    }
  end

  def backToIndex
    if(!session[:start_date].nil?)
      session[:start_date] = nil
    end
    if(!session[:end_date].nil?)
      session[:end_date] = nil
    end
    render 'schedules/show'
  end

  def backToList
    @surgeries = selectSurgeries(processDate(session[:start_date], session[:end_date]))
    render 'surgeries/show'
  end

end
