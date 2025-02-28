//
//  SummariesVM.swift
//  MainAppFeatures
//
//  Created by choijunios on 8/22/24.
//

import UIKit

import Entity
import RepositoryInterface
import UseCase
import CommonUI
import Util


import RxCocoa
import RxSwift

protocol SummariesVMable {
    
    // Input
    var currentSelectedCategoryForFilter: PublishSubject<MainCategory> { get }
    var searchButtonClicked: PublishSubject<Void> { get }
    
    // Output
    var alert: Driver<CapAlertVO> { get }
    var summaryItems: Driver<[SummaryItem]> { get }
    var presentSummaryLoading: Driver<Bool> { get }
    
    func createCellVM(videoId: Int) -> SummaryCellVM
    
    func requestPreferedCategories() -> [MainCategory]?
}

/// 요약화면 전체를 담당하는 VM입니다.
class SummaryListPageViewModel: SummariesVMable {
    
    @Injected private var summaryUseCase: SummaryUseCase
    @Injected private var summaryDetailRepository: SummaryDetailRepository
    @Injected private var userConfigRepository: UserConfigRepository
    
    // Navigation
    var showSummaryDetailPage: ((Int) -> ())?
    var presentSearchPage: (() -> ())?
    
    
    // Input
    let searchButtonClicked: PublishSubject<Void> = .init()
    let currentSelectedCategoryForFilter: PublishSubject<MainCategory> = .init()
    
    // Output
    private(set) var summaryItems: Driver<[SummaryItem]> = .empty()
    private(set) var alert: Driver<CapAlertVO> = .empty()
    private(set) var presentSummaryLoading: Driver<Bool> = .empty()
    
    private let disposeBag = DisposeBag()
    private let requestAllSummaryItems: BehaviorSubject<Void> = .init(value: ())
    private let presentSummaryLoadingPublisher: PublishSubject<Bool> = .init()
    private let summaryRequestErrorPublisher: PublishSubject<CapAlertVO> = .init()
    
    init() {
        
        // MARK: 스트림 연결 + 필터적용
        self.summaryItems = Observable
            .combineLatest(
                summaryUseCase.summariesStream,
                currentSelectedCategoryForFilter
            )
            .map { (items, category) in
                
                var filteredItems: [SummaryItem] = []
                
                if category == .all {
                    
                    filteredItems = items
                    
                } else {
                    
                    filteredItems = items.filter({ $0.mainCategory == category })
                    
                }
                
                let sortedList = filteredItems.sorted { lhs, rhs in
                    lhs.createdAt > rhs.createdAt
                }
                
                return sortedList
            }
            .asDriver(onErrorJustReturn: [])
        
        
        let requestAllSummaryItemsResult = requestAllSummaryItems
            .withUnretained(self)
            .flatMap { (vm, _) in
                vm.summaryUseCase
                    .requestFetchSummarriedItems()
            }
            .share()
        
        let initialRequestSuccess = requestAllSummaryItemsResult.compactMap { $0.value }
        let initialRequestFailure = requestAllSummaryItemsResult.compactMap { $0.error }
        
        
        // 앱이 다시 엑티비 되는 경우, 로컬에 저장된 요약목록을 확인합니다.
        // 최초 불러오기에 성공한 경우, 로컬에 저장된 요약목록을 확인합니다.
        
        let activeNotification = NotificationCenter.default.rx
            .notification(UIApplication.didBecomeActiveNotification)
            .map({ _ in })
            .asObservable()
        
        
        // MARK: Request summary
        Observable
            .merge(initialRequestSuccess, activeNotification)
            .withUnretained(self)
            .subscribe { (vm, _) in
                
                vm.requestSummary()
            }
            .disposed(by: disposeBag)
        
        
        
        // MARK: Search button
        searchButtonClicked
            .withUnretained(self)
            .subscribe(onNext: { (viewModel, _) in
                
                viewModel.presentSearchPage?()
            })
            .disposed(by: disposeBag)
        
        
        
        // MARK: Summary loading
        self.presentSummaryLoading = presentSummaryLoadingPublisher
            .asDriver(onErrorDriveWith: .never())
            
        
        
        let requestSummaryListErrorAlert = initialRequestFailure
            .map { error in
                CapAlertVO(title: "요약 불러오기 오류", message: error.message,
                    info: [
                        "닫기": { exit(0) },
                        "재시도하기": { [weak self] in
                            self?.requestAllSummaryItems.onNext(())
                        }
                    ]
                )
            }
        
        // MARK: Alert, 최초로 리스트를 불러오는 요청이 실패할 경우
        self.alert = Observable
            .merge(
                requestSummaryListErrorAlert,
                summaryRequestErrorPublisher
            )
            .asDriver(onErrorDriveWith: .never())
    }

    func createCellVM(videoId: Int) -> SummaryCellVM {
        
        let cellVM = SummaryCellVM(videoId: videoId)
        
        if let presentDetail = showSummaryDetailPage {
            
            cellVM.presentDetailPage = presentDetail
        }
        
        return cellVM
    }
    
    func requestPreferedCategories() -> [MainCategory]? {
        
        userConfigRepository.getPreferedCategories()
    }
    
    private func requestSummary() {
        
        let summaryRequestStream = summaryUseCase
            .requestCheckNewSummary()
        
        // 로딩 시작
        presentSummaryLoadingPublisher.onNext(true)
        
        summaryRequestStream
            .withUnretained(self)
            .subscribe(onNext: { viewModel, result in
                
                // 요약 요청 로딩 종료
                viewModel.presentSummaryLoadingPublisher.onNext(false)
                
                if case .failure(let error) = result {
                    
                    let alertVO: CapAlertVO = .init(
                        title: "요청 실패",
                        message: error.message
                    )
                    
                    // 에러 메시지 전송
                    viewModel.summaryRequestErrorPublisher
                        .onNext(alertVO)
                }
                
            })
            .disposed(by: disposeBag)
    }
}
